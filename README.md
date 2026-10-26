# WinPebble PNG to JPG

A lightweight Windows utility that converts PNG images to JPG directly from File Explorer.

**WinPebble — Small Windows tools. Simple fixes.**

## Microsoft Store version

[Get WinPebble PNG to JPG](https://apps.microsoft.com/detail/9NZC26K97WTT).
The published Store version 2.0.0.0 requires Windows 11 x64.

Version **2.0.1** is an unreleased compatibility update targeting Windows 10
version 2004 (build 19041) or later and Windows 11, x64. The owner waived further
Windows 10 runtime testing for this update; see the
[compatibility checklist](docs/WINDOWS_10_COMPATIBILITY.md).

The ZIP download, PowerShell implementation and installation instructions below
describe the historical **v1.0.0** release. They do not install the Store version.

## Download

Download the latest release:

https://github.com/WinPebble/png-to-jpg/releases/latest/download/WinPebble-PNG-to-JPG.zip

Current public release: **v1.0.0**

SHA-256:

`5e9ba8c06d43ac2bf8a3dd5557d843246e6af7dbe4ee1c29bde3cfcf0c842d00`

## What it does

PNG to JPG adds a **Convert PNG to JPG** command to the Windows File Explorer context menu.

It is designed for a simple workflow: select one or more PNG files, right-click, and convert them to JPG without opening a separate application.

## Features

- Convert one or multiple PNG files from File Explorer.
- Keeps the original pixel dimensions.
- Does not resize images.
- JPEG quality is set to 100.
- Transparent areas are composited onto a white background.
- Original PNG files are preserved.
- JPG files are created beside the source PNG files.
- Existing files are not overwritten; a numbered filename is created instead.
- No background service.
- No telemetry or analytics.
- No user account required.
- No Administrator permission required for normal installation.
- The context-menu entry is intended for PNG files only.

## Example

```text
image.png
→ image.jpg
```

If `image.jpg` already exists, the tool creates a numbered alternative such as:

```text
image_1.jpg
```

## Requirements

- Windows 10 or Windows 11
- PowerShell / .NET components included with supported Windows versions

## Installation

1. Download the latest release ZIP.
2. Extract the ZIP to a local folder.
3. Run the included installation/update batch file.
4. After installation, right-click a PNG file in File Explorer.
5. Select **Convert PNG to JPG**.

The utility uses a per-user Windows Registry integration and does not require Administrator privileges for normal installation.

## Usage

1. Select one or more `.png` files in File Explorer.
2. Right-click the selection.
3. Choose **Convert PNG to JPG**.
4. The JPG output is created in the same folder as each source PNG.

## Uninstallation

Use the uninstall/remove-menu script included in the release package to remove the File Explorer context-menu integration.

The tool does not install a background service.

## Privacy

PNG to JPG processes images locally on your computer.

- No user data is collected.
- No image data is transmitted.
- No telemetry is included.
- No account is required.

## Internet access

The conversion process does not require an Internet connection.

## Technology

The current implementation is based on:

- PowerShell
- .NET / `System.Drawing`
- Windows per-user Registry context-menu integration

## Source

The original `v1.0.0` release package has been verified against the SHA-256
recorded for the published GitHub release.

The exact historical package files are preserved under [`src/`](src/).

See [`SOURCE_STATUS.md`](SOURCE_STATUS.md) for verification details and known
implementation notes.

Future releases should publish their corresponding source and release assets together.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## License

This project is licensed under the MIT License.

See [`LICENSE`](LICENSE).

## Website

https://winpebble.com

---

No ads inside the app. No tracking. No account required.

## v2 native development

Store version 2.0.0.0 is live; version 2.0.1 is a Windows 10 compatibility
candidate, not released. The native x64 WIC core and packaged Explorer command
use the [shared WinPebble brand icon](branding/SHARED_BRAND_ICON.md).

Historical [Gate A](docs/GATE_A_DISCOVERY.md), [Gate B](docs/GATE_B_VALIDATION.md),
[Gate C](docs/GATE_C_VALIDATION.md) and [Gate D](docs/GATE_D_STORE_CANDIDATE.md)
records describe the original 2.0.0 candidate. They are not validation evidence
for the new update. See [Windows 10 validation](docs/WINDOWS_10_COMPATIBILITY.md)
for remaining release gates. Historical v1 files under src/ are preserved.
