"""Check that release verification rejects a tampered update feed."""
from pathlib import Path
import base64
import subprocess
import sys
import xml.etree.ElementTree as ET

version = sys.argv[1].removeprefix("v")
feed_path = Path("dist/appcast.xml")
original = feed_path.read_bytes()
namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", namespace)
command = ["swift", "-module-cache-path", ".build/update-module-cache", "Scripts/verify-update.swift", version]

def verify():
    return subprocess.run(command, capture_output=True, text=True)

valid = verify()
assert valid.returncode == 0, valid.stdout + valid.stderr
cases = [
    (f".//{{{namespace}}}version", None, version + "-corrupt", "another version"),
    (".//enclosure", "url", "https://example.invalid/update.zip", "download URL"),
    (".//enclosure", "length", "0", "archive length"),
    (".//enclosure", f"{{{namespace}}}edSignature", base64.b64encode(bytes(64)).decode(), "signature does not match"),
]
try:
    for selector, attribute, value, expected_error in cases:
        tree = ET.fromstring(original)
        node = tree.find(selector)
        if attribute:
            node.set(attribute, value)
        else:
            node.text = value
        feed_path.write_bytes(ET.tostring(tree, encoding="utf-8", xml_declaration=True))
        result = verify()
        assert result.returncode != 0 and expected_error in result.stderr, result.stdout + result.stderr
        print(f"Rejected tampered {attribute or 'version'}.")
finally:
    feed_path.write_bytes(original)
assert verify().returncode == 0, "The restored feed failed verification."
