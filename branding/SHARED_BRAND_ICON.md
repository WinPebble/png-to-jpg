# Shared WinPebble branding

On 2026-10-16, the user requested the shared WinPebble logo for tools instead of separate product logos. PNG to JPG v2 now uses that mark for its executable, Explorer command and full development package assets. Product names, package identities and conversion behavior are unchanged.

The existing supplied brand files were copied byte-for-byte from the sibling PDF-to-Image project's current shared-brand preparation:

- `branding/WinPebble-Pebble-Mark-512.png`: the supplied 512-pixel source mark.
- `branding/WinPebble.ico`: the supplied 32/44/150-pixel PNG-frame icon, embedded as EXE resource 101.
- `packaging/Assets/Command.ico`: identical bytes to the shared ICO, returned by IExplorerCommand.GetIcon.
- Package PNG logos: exact ready-sized supplied 44, 150 and 50-pixel images from that project's package/Assets. No recreation or resizing.

The historical v1 files in src/ retain their original artwork. No other repository, authoritative Project Master Brief, website or Store listing is changed by this commit. The shared-brand direction should be incorporated into the authoritative Project source; this repository document does not claim that synchronization has happened.

This is unreleased development preparation. Build, packed payload and EXE resource checks are recorded with the development artifact. Store-delivered icons and scaling still require installation validation in the Store packaging gate.
