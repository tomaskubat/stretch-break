"""Exercise release verification with isolated assets and disposable Ed25519 keys."""
from pathlib import Path
import argparse
import base64
import hashlib
import os
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
os.environ.pop("SPARKLE_PRIVATE_KEY", None)
NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", NAMESPACE)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("version", nargs="?", help="Version of the already built and packaged app, optionally prefixed with v")
options = parser.parse_args()


def run(*arguments, input=None):
    result = subprocess.run(arguments, input=input, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"{arguments[0]} failed: {result.stdout}{result.stderr}")
    return result.stdout


def write_plist(path, changes):
    with path.open("rb") as stream:
        value = plistlib.load(stream)
    value.update(changes)
    with path.open("wb") as stream:
        plistlib.dump(value, stream)


def archive(source, destination, source_snapshot=False):
    flags = ["--norsrc", "--noextattr"] if source_snapshot else ["--sequesterRsrc"]
    run("ditto", "-c", "-k", *flags, "--keepParent", str(source), str(destination))


class ReleaseVerificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="StretchBreak-release-tests-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.workspace = Path(cls.temporary.name)
        cls.verifier = cls.workspace / "verify-release"
        cls.signer = cls.workspace / "sign-fixture"
        for source, executable in [("verify-release.swift", cls.verifier), ("test-update-signing.swift", cls.signer)]:
            run("swiftc", "-module-cache-path", str(ROOT / ".build/update-module-cache"),
                str(ROOT / "Scripts" / source), "-o", str(executable))
        with (ROOT / "dist/Release/StretchBreak.app/Contents/Info.plist").open("rb") as stream:
            version = plistlib.load(stream)["CFBundleVersion"]
        cls.version = options.version.removeprefix("v") if options.version else version
        if cls.version != version:
            raise RuntimeError("Build and package the requested version before running verification tests.")
        cls.app_name = f"StretchBreak-{cls.version}-arm64.zip"
        cls.source_name = f"StretchBreak-{cls.version}-source.zip"
        cls.update_name = f"StretchBreak-{cls.version}-update.zip"
        cls.asset_names = [cls.app_name, cls.source_name, cls.update_name, "appcast.xml"]
        cls.protected_files = [ROOT / "dist" / name for name in cls.asset_names + ["SHA256SUMS.txt"]]
        cls.protected_files += [ROOT / "Resources/Info.plist", ROOT / "dist/Release/StretchBreak.app/Contents/Info.plist"]
        cls.production_snapshot = {path: cls.file_digest(path) for path in cls.protected_files}
        cls.addClassCleanup(cls.assert_distribution_unchanged)
        cls.private_key = cls.workspace / "private-key"
        cls.public_key = cls.workspace / "public-key"
        run(str(cls.signer), "key", str(cls.private_key), str(cls.public_key))

        # The source ZIP supplies the accepted source snapshot, without a second file inventory.
        run("ditto", "-x", "-k", str(ROOT / "dist" / cls.source_name), str(cls.workspace / "snapshot"))
        cls.reference = cls.workspace / "original"
        shutil.move(str(cls.workspace / "snapshot/StretchBreak-source"), cls.reference)
        source_items = list(cls.reference.iterdir())
        cls.original_app = cls.reference / "dist/Release/StretchBreak.app"
        cls.original_app.parent.mkdir(parents=True)
        run("ditto", str(ROOT / "dist/Release/StretchBreak.app"), str(cls.original_app))
        key = cls.public_key.read_text()
        write_plist(cls.original_app / "Contents/Info.plist", {"SUPublicEDKey": key})
        write_plist(cls.reference / "Resources/Info.plist", {"SUPublicEDKey": key})
        run("codesign", "--force", "--sign", "-", str(cls.original_app))
        license_path = cls.reference / ".build/artifacts/sparkle/Sparkle/LICENSE"
        license_path.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / ".build/artifacts/sparkle/Sparkle/LICENSE", license_path)
        cls.baseline = cls.reference / "dist"

        portable = cls.workspace / "portable/StretchBreak"
        portable.mkdir(parents=True)
        run("ditto", str(cls.original_app), str(portable / "StretchBreak.app"))
        shutil.copyfile(cls.reference / "LICENSE", portable / "LICENSE")
        guide = (cls.reference / "Docs/Install.md").read_text().splitlines()
        guide[0] = f"# StretchBreak {cls.version} pro Apple Silicon"
        (portable / "Install.md").write_text("\n".join(guide) + "\n")
        archive(portable, cls.baseline / cls.app_name)
        source = cls.workspace / "source/StretchBreak-source"
        source.mkdir(parents=True)
        for item in source_items:
            run("ditto", "--norsrc", "--noextattr", str(item), str(source / item.name))
        archive(source, cls.baseline / cls.source_name, source_snapshot=True)
        archive(cls.original_app, cls.baseline / cls.update_name)

        feed = ET.Element("rss", {"version": "2.0"})
        item = ET.SubElement(ET.SubElement(feed, "channel"), "item")
        for name, value in [("version", cls.version), ("minimumSystemVersion", "14.0"), ("hardwareRequirements", "arm64")]:
            ET.SubElement(item, f"{{{NAMESPACE}}}{name}").text = value
        ET.SubElement(item, "enclosure", {
            "url": f"https://github.com/tomaskubat/stretch-break/releases/download/v{cls.version}/{cls.update_name}",
            "length": str((cls.baseline / cls.update_name).stat().st_size),
            f"{{{NAMESPACE}}}edSignature": cls.signature(cls.baseline / cls.update_name),
        })
        ET.ElementTree(feed).write(cls.baseline / "appcast.xml", encoding="utf-8", xml_declaration=True)
        cls.write_manifest(cls.baseline)
        cls.original_manifest = (cls.baseline / "SHA256SUMS.txt").read_bytes()

    @classmethod
    def file_digest(cls, path):
        return hashlib.sha256(path.read_bytes()).digest() if path.exists() else None

    @classmethod
    def assert_distribution_unchanged(cls):
        for path, expected in cls.production_snapshot.items():
            if cls.file_digest(path) != expected:
                raise AssertionError(f"Verification tests changed an original release file: {path}")

    @classmethod
    def signature(cls, path):
        result = cls.workspace / "signature"
        run(str(cls.signer), "sign", str(cls.private_key), str(path), str(result))
        return result.read_text()

    @classmethod
    def write_manifest(cls, assets):
        names = [name for name in cls.asset_names if (assets / name).exists()]
        records = [f"{hashlib.sha256((assets / name).read_bytes()).hexdigest()}  {name}\n" for name in names]
        (assets / "SHA256SUMS.txt").write_text("".join(records))

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=self.workspace, prefix="candidate-")
        self.addCleanup(temporary.cleanup)
        self.assets = Path(temporary.name)
        for name in self.asset_names + ["SHA256SUMS.txt"]:
            shutil.copyfile(self.baseline / name, self.assets / name)
        self.assertEqual((self.baseline / "SHA256SUMS.txt").read_bytes(), self.original_manifest)

    def verify(self, mode="signed", error=None, before_extraction=True, reference=None):
        result = subprocess.run([str(self.verifier), mode, self.version, str(reference or self.reference), str(self.assets)],
                                capture_output=True, text=True)
        if error is None:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(error, result.stderr)
            if before_extraction:
                self.assertNotIn("extracting archives", result.stdout)
        return result

    def alter_feed(self, selector, value, attribute=None):
        path = self.assets / "appcast.xml"
        tree = ET.parse(path)
        node = tree.find(selector)
        if attribute:
            node.set(attribute, value)
        else:
            node.text = value
        tree.write(path, encoding="utf-8", xml_declaration=True)
        self.write_manifest(self.assets)

    def test_accepts_signed_release_and_exact_published_copies(self):
        self.verify("signed")
        self.verify("published")

    def test_existing_appcast_and_package_commands_use_shared_verification(self):
        root = self.assets / "release-workspace"
        run("ditto", str(self.reference), str(root))
        tools = root / ".build/artifacts/sparkle/Sparkle/bin"
        tools.symlink_to(ROOT / ".build/artifacts/sparkle/Sparkle/bin", target_is_directory=True)
        environment = os.environ.copy()
        environment["SPARKLE_PRIVATE_KEY"] = base64.b64encode(self.private_key.read_bytes()).decode()
        result = subprocess.run(["zsh", str(root / "Scripts/generate-appcast.sh"), self.version],
                                env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Verified signed release assets", result.stdout)
        output = run("zsh", str(root / "Scripts/verify-package.sh"), self.version)
        self.assertIn("Verified distribution release assets", output)

    def test_no_feed_is_allowed_only_for_distribution(self):
        (self.assets / "appcast.xml").unlink()
        self.write_manifest(self.assets)
        self.verify("distribution")
        self.verify("signed", "requires appcast.xml")
        self.verify("published", "requires appcast.xml")

    def test_rejects_changed_feed_version(self):
        self.alter_feed(f".//{{{NAMESPACE}}}version", self.version + "-corrupt")
        self.verify(error="another version")

    def test_rejects_changed_download_url(self):
        self.alter_feed(".//enclosure", "https://example.invalid/update.zip", "url")
        self.verify(error="download URL")

    def test_rejects_changed_archive_length(self):
        self.alter_feed(".//enclosure", "0", "length")
        self.verify(error="archive length")

    def test_rejects_invalid_signature_even_with_correct_checksums(self):
        self.alter_feed(".//enclosure", base64.b64encode(bytes(64)).decode(), f"{{{NAMESPACE}}}edSignature")
        self.verify(error="signature does not match")

    def test_rejects_corrupted_published_archive(self):
        with (self.assets / self.update_name).open("ab") as stream:
            stream.write(b"corrupt")
        self.verify("published", "checksum mismatch")

    def test_rejects_replaced_published_manifest(self):
        path = self.assets / "SHA256SUMS.txt"
        path.write_text(path.read_text().replace("  ", " "))
        self.verify("published", "differs from the original release manifest")

    def test_rejects_published_invalid_signature(self):
        self.alter_feed(".//enclosure", base64.b64encode(bytes(64)).decode(), f"{{{NAMESPACE}}}edSignature")
        self.verify("published", "differs from the original release manifest")

    def test_rejects_modified_archive_with_recomputed_published_checksums(self):
        with (self.assets / self.update_name).open("ab") as stream:
            stream.write(b"replacement")
        self.write_manifest(self.assets)
        self.verify("published", "differs from the original release manifest")

    def test_rejects_other_version_in_published_latest_feed(self):
        self.alter_feed(f".//{{{NAMESPACE}}}version", self.version + "-other")
        self.verify("published", "differs from the original release manifest")

    def test_rejects_unexpected_published_asset_name(self):
        path = self.assets / "SHA256SUMS.txt"
        path.write_text(path.read_text().replace(self.app_name, "unexpected.zip"))
        self.verify("published", "Unexpected asset inventory")

    def test_rejects_authenticated_update_with_extra_contents(self):
        stage = self.assets / "malformed-update"
        stage.mkdir()
        run("ditto", str(self.original_app), str(stage / "StretchBreak.app"))
        (stage / "extra.txt").write_text("unexpected")
        # Archive the directory contents, rather than adding another parent directory.
        run("ditto", "-c", "-k", "--sequesterRsrc", str(stage), str(self.assets / self.update_name))
        self.alter_feed(".//enclosure", str((self.assets / self.update_name).stat().st_size), "length")
        self.alter_feed(".//enclosure", self.signature(self.assets / self.update_name), f"{{{NAMESPACE}}}edSignature")
        self.verify(error="must contain only StretchBreak.app", before_extraction=False)

    def repack_portable(self, change):
        stage = self.assets / "portable"
        run("ditto", "-x", "-k", str(self.assets / self.app_name), str(stage))
        change(stage / "StretchBreak/StretchBreak.app")
        archive(stage / "StretchBreak", self.assets / self.app_name)
        self.write_manifest(self.assets)

    def test_rejects_invalid_app_codesign_after_authentication(self):
        self.repack_portable(lambda app: write_plist(app / "Contents/Info.plist", {"FixtureTampering": True}))
        self.verify(error="codesign failed", before_extraction=False)

    def test_rejects_wrong_architecture_after_authentication(self):
        def replace_executable(app):
            run("clang", "-target", "x86_64-apple-macos14", "-x", "c", "-", "-o",
                str(app / "Contents/MacOS/StretchBreak"), input="int main(void) { return 0; }\n")
            run("codesign", "--force", "--sign", "-", str(app))
        self.repack_portable(replace_executable)
        self.verify(error="must be arm64", before_extraction=False)

    def test_rejects_changed_source_snapshot(self):
        stage = self.assets / "source"
        run("ditto", "-x", "-k", str(self.assets / self.source_name), str(stage))
        (stage / "StretchBreak-source/README.md").write_text("different source")
        archive(stage / "StretchBreak-source", self.assets / self.source_name, source_snapshot=True)
        self.write_manifest(self.assets)
        self.verify(error="diff failed", before_extraction=False)

    def test_accepts_original_source_snapshot_from_before_the_glossary(self):
        reference = self.assets / "original-without-glossary"
        run("ditto", str(self.reference), str(reference))
        (reference / "CONTEXT.md").unlink()
        stage = self.assets / "source"
        run("ditto", "-x", "-k", str(self.assets / self.source_name), str(stage))
        (stage / "StretchBreak-source/CONTEXT.md").unlink()
        archive(stage / "StretchBreak-source", self.assets / self.source_name, source_snapshot=True)
        self.write_manifest(self.assets)
        for name in self.asset_names + ["SHA256SUMS.txt"]:
            shutil.copyfile(self.assets / name, reference / "dist" / name)
        self.verify("published", reference=reference)


if __name__ == "__main__":
    unittest.main(argv=[__file__], verbosity=2)
