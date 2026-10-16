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

The first user run signed and verified both clones and installed the initial
package with matching payload hashes, but stopped at COM activation from the
Administrator process. Cleanup reported zero errors. The elevated caller differs
from normal Explorer; its role in the failure is a hypothesis, not a confirmed
app defect. The revised runner uses the interactive Shell broker to launch a
worker that rejects elevation, retains its transcript/result and tests registered
COM. The probe now prints the activation HRESULT. A fresh lifecycle run is
required; successful signing alone is not a deployment PASS.

The second run's worker explicitly reported Elevated=true, proving that creating
a new Shell.Application in the Administrator process did not obtain Explorer's
token. The runner now obtains Application from the existing desktop view via
ShellWindows.FindWindowSW (SWC_DESKTOP), as described in Microsoft's
[Explorer delegation guidance](https://devblogs.microsoft.com/oldnewthing/20131118-00/?p=2643).
An unelevated-worker preflight now runs before certificate creation or deployment.
The second run also reported zero cleanup errors. The full elevated-to-unelevated
lifecycle still requires the user's next Administrator run.

The third run confirmed Elevated=false, but its Windows PowerShell worker could
not resolve Get-FileHash. The shell test now hashes through streaming .NET SHA256
and uses UTF-8 BOM so Windows PowerShell preserves Vietnamese fixture names.
The full direct shell workflow was successfully run through the actual desktop
broker against the extracted CI binaries (single/multi/Unicode/collision/source
hash checks). This direct preflight now runs before creating certificates or
installing packages. Registered signed deployment still needs a fresh full run;
direct DLL test success does not replace that checkpoint.

The fourth run passed signed initial installation, installed binary hash checks
and the complete registered COM workflow with Elevated=false. Update then failed
with 0x80073D02 because the target package was still in use after COM testing;
cleanup reported zero errors. The update now uses Add-AppxPackage's documented
ForceTargetApplicationShutdown option to close processes associated with this
test package. It does not use ForceApplicationShutdown (which also affects
dependencies), kill arbitrary dllhost processes or restart Explorer. The report
records this policy. Successful local forced update will not establish deferred
Store update behavior; the full lifecycle remains pending a fresh run.

Reference: [Add-AppxPackage target shutdown option](https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage#-forcetargetapplicationshutdown).

```powershell
Set-Location 'C:\Users\aries\Projects\WinPebble\png-to-jpg'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-SignedDeployment.ps1
```

Reference: [Microsoft certificate creation/trust guidance](https://learn.microsoft.com/en-us/windows/msix/package/create-certificate-package-signing).
