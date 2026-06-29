$runningOnWindows = $false

if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    $runningOnWindows = $IsWindows
} else {
    $runningOnWindows = $env:OS -eq 'Windows_NT'
}

if (-not $runningOnWindows) {
    Write-Error 'This script only runs on Windows.'
    exit 1
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
        Write-Error 'Administrator rights required and gsudo not found. Install gsudo or re-run elevated.'
        exit 1
    }
    Write-Host 'Elevating with gsudo...'
    gsudo pwsh -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

$sourceDir = Join-Path $PSScriptRoot 'fonts'

if (-not (Test-Path -Path $sourceDir)) {
    Write-Error "Fonts folder not found: $sourceDir"
    exit 1
}

$destinationDir = Join-Path $env:WINDIR 'Fonts'

$registryPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$extensions = @('.ttf', '.otf', '.ttc', '.otc')
$fontFiles = Get-ChildItem -Path $sourceDir -File -Recurse | Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }

if ($fontFiles.Count -eq 0) {
    Write-Host "No supported font files found in $sourceDir"
    exit 0
}

$installed = 0
$skipped = 0
$failed = 0

foreach ($fontFile in $fontFiles) {
    $destinationFile = Join-Path $destinationDir $fontFile.Name

    if (Test-Path -Path $destinationFile) {
        Write-Host "Skipping already installed font: $($fontFile.Name)"
        $skipped++
        continue
    }

    try {
        Copy-Item -Path $fontFile.FullName -Destination $destinationFile -Force

        $kind = if ($fontFile.Extension.ToLowerInvariant() -eq '.otf') { 'OpenType' } else { 'TrueType' }
        $valueName = "$($fontFile.BaseName) ($kind)"

        New-ItemProperty -Path $registryPath -Name $valueName -Value $fontFile.Name -PropertyType String -Force | Out-Null

        Write-Host "Installed font: $($fontFile.Name)"
        $installed++
    } catch {
        Write-Warning "Failed to install $($fontFile.Name): $($_.Exception.Message)"
        $failed++
    }
}

Write-Host "Font install complete. Installed: $installed, Skipped: $skipped, Failed: $failed"
