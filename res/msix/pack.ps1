# Pack ./shamarrconnect (Flutter Windows Release + extras) as a Store MSIX.
# Identity is locked to Partner Center: SiSLLC.shamarrdesk.
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Manifest = "",
    [string]$Assets = ""
)

$ErrorActionPreference = "Stop"

function Convert-StoreVersion([string]$v) {
    # Store requires revision (fourth part) to be 0.
    # Tag 1.4.9-sc22 → 1.4.22.0
    if ($v -match '^(\d+)\.(\d+)\.(\d+)-sc(\d+)$') {
        return "$($Matches[1]).$($Matches[2]).$($Matches[4]).0"
    }
    if ($v -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)$') {
        return "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
    }
    throw "Cannot map '$v' to a Store MSIX version (want 1.4.9-sc22 → 1.4.22.0)"
}

$msixVersion = Convert-StoreVersion $Version
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Manifest) { $Manifest = Join-Path $here "AppxManifest.xml" }
if (-not $Assets) { $Assets = Join-Path $here "Assets" }

$Source = (Resolve-Path $Source).Path
$OutDir = (New-Item -ItemType Directory -Force -Path $OutDir).FullName
$stage = Join-Path $OutDir "msix-stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Path $stage | Out-Null

Write-Host "Staging from $Source"
Get-ChildItem -Path $Source -Force | ForEach-Object {
    $skip = @(
        "usbmmidd_v2",
        "drivers",
        "Win32"
    ) -contains $_.Name
    if ($skip) {
        Write-Host "  skip $($_.Name) (kernel driver / not for Store)"
        return
    }
    Copy-Item -Recurse -Force $_.FullName (Join-Path $stage $_.Name)
}

$exe = Join-Path $stage "ShamarrConnect.exe"
if (-not (Test-Path $exe)) {
    throw "ShamarrConnect.exe not in $stage — Windows build folder is wrong"
}

Copy-Item -Recurse -Force $Assets (Join-Path $stage "Assets")
$manifestOut = Join-Path $stage "AppxManifest.xml"
$text = (Get-Content -Raw $Manifest) -replace 'Version="0\.0\.0\.0"', "Version=`"$msixVersion`""
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestOut, $text, $utf8)

$makeappx = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter makeappx.exe |
    Where-Object { $_.FullName -match '\\x64\\makeappx\.exe$' } |
    Sort-Object FullName |
    Select-Object -Last 1
if (-not $makeappx) { throw "makeappx.exe not found (Windows SDK)" }
Write-Host "makeappx: $($makeappx.FullName)"

$msixName = "SiSLLC.shamarrdesk_${msixVersion}_x64.msix"
$msixPath = Join-Path $OutDir $msixName
if (Test-Path $msixPath) { Remove-Item -Force $msixPath }

& $makeappx.FullName pack /d $stage /p $msixPath /o /l
if ($LASTEXITCODE -ne 0) { throw "makeappx failed: $LASTEXITCODE" }

$upload = Join-Path $OutDir "SiSLLC.shamarrdesk_${msixVersion}_x64.msixupload"
if (Test-Path $upload) { Remove-Item -Force $upload }
Compress-Archive -Path $msixPath -DestinationPath $upload -Force

Write-Host "MSIX $msixPath"
Write-Host "UPLOAD $upload"
Write-Host "STORE_VERSION=$msixVersion"
