# actionlint maintenance

`Scripts/check-config.sh` pins `ACTIONLINT_VERSION` and `ACTIONLINT_SHA256` for the upstream `darwin_arm64` release archive. The archive name, download URL, and `.build` directory derive from that version. Both CI and the release workflow run this script. It verifies the pinned SHA-256 before extracting or executing actionlint.

## Updating the pin

1. Choose a stable release from [rhysd/actionlint](https://github.com/rhysd/actionlint/releases) and read its release notes.
2. Download its Apple Silicon archive and checksum list. Replace `X.Y.Z` below with the chosen version, without `v`:

   ```sh
   ACTIONLINT_VERSION="X.Y.Z"
   ACTIONLINT_ARCHIVE="actionlint_${ACTIONLINT_VERSION}_darwin_arm64.tar.gz"
   ACTIONLINT_CHECKSUMS="actionlint_${ACTIONLINT_VERSION}_checksums.txt"
   ACTIONLINT_DOWNLOAD_DIR="$(mktemp -d)"
   gh release download "v${ACTIONLINT_VERSION}" --repo rhysd/actionlint \
       --pattern "$ACTIONLINT_ARCHIVE" --pattern "$ACTIONLINT_CHECKSUMS" \
       --dir "$ACTIONLINT_DOWNLOAD_DIR"
   gh attestation verify "$ACTIONLINT_DOWNLOAD_DIR/$ACTIONLINT_ARCHIVE" \
       --repo rhysd/actionlint
   shasum -a 256 "$ACTIONLINT_DOWNLOAD_DIR/$ACTIONLINT_ARCHIVE"
   ```

3. Require attestation verification to pass and compare the calculated SHA-256 with the exact archive's entry in the downloaded checksum list. Upstream provides [artifact attestations](https://github.com/rhysd/actionlint/blob/main/docs/install.md#prebuilt-binaries) starting with version 1.7.11. This authenticates the downloaded archive before adopting its checksum as the new pin. Do not extract or run it during this step.
4. Change `ACTIONLINT_VERSION` and `ACTIONLINT_SHA256` in `Scripts/check-config.sh` in the same PR. Keep the checksum as a literal in the repository. Fetching a checksum at CI runtime would remove the independent pin.
5. Run `zsh -n Scripts/check-config.sh` and `./Scripts/check-config.sh` on Apple Silicon macOS. Review the diff and the PR's `Tests and distribution` result, then merge manually.

## Automatic update options

[Dependabot's supported ecosystems](https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories) do not include arbitrary shell downloads. Its GitHub Actions updater handles `uses: owner/repo@version` references. Declaring `ACTIONLINT_VERSION` once therefore does not enable Dependabot updates for this tool. Sparkle remains managed by the existing Swift configuration.

A separate scheduled GitHub Actions workflow could propose actionlint updates using the same process above. It would find the latest stable upstream release, verify the archive's attestation and published checksum, change both literals, and open a PR with [GitHub CLI](https://cli.github.com/manual/gh_pr_create). Limit it to one open actionlint update PR and retain manual merging and the existing CI checks. This is the recommended route if automatic proposals are added later because it keeps archive verification and requires no additional update service.

That updater would need `contents: write` and `pull-requests: write`, plus the repository setting that allows GitHub Actions to create PRs. [GitHub documents](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow) that PRs opened or updated with `GITHUB_TOKEN` require approval before their CI workflows run. A GitHub App token can allow those workflows to start automatically. The updater and its permissions are not enabled by this refactoring; actionlint updates use the manual procedure above.
