# Gate A discovery — 2026-10-16

Status: repository/release/starter audit complete. Project-hosted authoritative source could not be accessed; the newest locally supplied brief is v3.0 (2026-10-08), not the older v2.9 file without a suffix. This provenance limitation remains explicit.

## Verified sources

- Remote: https://github.com/WinPebble/png-to-jpg, main `c04e8f55ac1b37578c0b81a98aab15ad398be9fa`.
- At discovery: only main, no open PRs, no Actions workflows. New work is isolated on `v2/store-modernization`.
- Release v1.0.0: 354,691 bytes. Downloaded asset SHA-256 `5e9ba8c06d43ac2bf8a3dd5557d843246e6af7dbe4ee1c29bde3cfcf0c842d00` matches GitHub API digest and brief. ZIP contents match historical src files after Git checkout LF/CRLF normalization; binary icons match exactly.
- Starter archive SHA-256 `dcebb5fe45dc116fc91c211418c5656298d3b1868a5565b28bbac8977d384997`. Eight source files; supplied without build evidence.
- Reference PDF repository main tree `8c32618ffef8b002a3a21a9af3236110375b0931` has separate dev and Store MSIX scripts/workflows. No identity copied.

## Conflicts and limitations

- Historical v1 collision names are `_1`, `_2`; approved v2 contract requires `(2)`, `(3)`. Preserve src/ and implement new names only in native/.
- Historical v1 silently swallows conversion errors. v2 reports a single failure summary; --quiet returns status and UTF-8 stderr for automation.
- Repo v1 docs claim Windows 10/11; this does not establish v2 support. Core tested on Windows 11 build 26300 x64 only. Explorer/Store validation belongs to later gates.
- Local brief v3.0 describes older PDF Store status. Reference repository is read for architecture, not proof of current Store availability.
- No access to current Project-hosted Master Brief was established. No authoritative brief or public website was changed.

## Build plan and implementation

- Preserve all historical src files. Native C++20 WIC EXE, static MSVC runtime; OS DLL dependencies only.
- Use MSVC 2022 x64 + SDK 26100 locally; CMake x64 Release on windows-2025 CI. Warnings treated as errors.
- RAII temp ownership, exclusive create, COM destruction before cleanup; atomic same-folder rename without replacement. Derive every collision candidate from original PNG stem.
- Check and read back ImageQuality=1.0; check resolution and negotiated BGR format. Validate actual JPEG quantization tables in tests.
- Bounded row buffers replace full-image BGRA+BGR allocation. Reject zero/over-65535 JPEG dimensions. PNG chunk bounds/CRC check guards WIC recovery of truncated files.
- Run fixtures, races, input hashes, error cleanup and measured v1 comparison. Publish development artifacts via Actions only, no GitHub Release, merge or Store submission.
