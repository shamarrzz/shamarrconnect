# Microsoft Store MSIX (ShamarrDesk)

Locked Partner Center identity:

- **Name:** `SiSLLC.shamarrdesk`
- **Publisher:** `CN=947D66EB-CE27-43A4-AEC1-002D59118CD0`
- **PublisherDisplayName:** `SiSLLC` (must match Partner Center, not the legal name)
- **Display name:** ShamarrConnect (listing name is shamarrdesk)

`pack.ps1` runs on the Windows CI runner after `./shamarrconnect` is built.
It **drops** `usbmmidd_v2` and printer `drivers/` (kernel drivers — Store will not take them).
The package is **unsigned**; the Store re-signs on submit.

Version mapping: tag `1.4.9-sc22` → MSIX `1.4.22.0` (Store forces the fourth number to 0).

Local (Windows SDK):

```powershell
.\res\msix\pack.ps1 -Source .\shamarrconnect -OutDir .\SignOutput -Version 1.4.9-sc22
```
