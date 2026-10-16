# Local signed MSIX deployment test

Run `scripts/Test-SignedDeployment.ps1` from Administrator PowerShell in this
repository. Input defaults to the exact unsigned CI package that passed WACK,
source `5fe39357385874ffb53e7fc9347b93b48f7ffead`, SHA-256
`1b72f3f81d54eee32c04c812420de937f38dcbd0fd980e8f5de988efe244f6fc`.

The script refuses to replace an installed official PNG to JPG package or run
alongside its development package. Other WinPebble packages are checked before
and after the test. It creates a temporary non-exportable code-signing leaf key,
trusts its public certificate in LocalMachine TrustedPeople, and signs local
copies. It does not add a trusted root, export a private key, change Developer
Mode, modify legacy menu preferences, or change the original unsigned MSIX.

Tests:

1. Install a signed copy of the reviewed 2.0.0.0 package; verify official PFN,
   non-development deployment, installed binary hashes and registered COM
   conversion (single/multi/Unicode/collision, original hashes).
2. Update to a locally repacked 2.0.0.1 clone; verify the same binary hashes,
   registered COM workflow and LocalState marker retention.
3. Uninstall; verify package removal and failed COM activation.
4. Remove exactly the newly created trust certificate and private key in finally,
   even if testing fails. Report cleanup errors rather than claiming PASS.

The artificial update changes only the package version. Its binaries retain
2.0.0.0 candidate metadata. It tests MSIX update mechanics, not a v1-to-v2 upgrade
or Store-delivered update. Neither signed local clone is a submission artifact.
No v1 installation is removed or migrated. No Store certification is claimed.

Reports and public certificates are retained under
`artifacts/store/deployment-<guid>/`; no private key file is written. Read
`report.json` before accepting the checkpoint. If the host terminates abruptly,
use its recorded certificate thumbprint/package name to inspect and clean only
the test artifacts; normal try/finally cleanup cannot run after host termination.

```powershell
Set-Location 'C:\Users\aries\Projects\WinPebble\png-to-jpg'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-SignedDeployment.ps1
```

Reference: [Microsoft certificate creation/trust guidance](https://learn.microsoft.com/en-us/windows/msix/package/create-certificate-package-signing).
