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

$sourceDir = $PSScriptRoot
$destinationDir = Join-Path $env:USERPROFILE '.config'

if (-not (Test-Path -Path $destinationDir)) {
    New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
}

$starshipSource = Join-Path $sourceDir 'starship.toml.win'
$profileSource = Join-Path $sourceDir 'profile.ps1'
$localConfigProfile = Join-Path $destinationDir 'profile.ps1'

if (-not (Test-Path -Path $starshipSource)) {
    Write-Error "Missing source file: $starshipSource"
    exit 1
}

if (-not (Test-Path -Path $profileSource)) {
    Write-Error "Missing source file: $profileSource"
    exit 1
}

Copy-Item -Path $starshipSource -Destination (Join-Path $destinationDir 'starship.toml') -Force
Copy-Item -Path $profileSource -Destination (Join-Path $destinationDir 'profile.ps1') -Force

$targetProfile = $PROFILE.CurrentUserCurrentHost
$targetProfileDir = Split-Path -Path $targetProfile -Parent

if (-not (Test-Path -Path $targetProfileDir)) {
    New-Item -Path $targetProfileDir -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -Path $targetProfile)) {
    New-Item -Path $targetProfile -ItemType File -Force | Out-Null
}

$sourceProfileResolved = (Resolve-Path -Path $localConfigProfile).Path
$targetProfileResolved = (Resolve-Path -Path $targetProfile).Path

if ($sourceProfileResolved -ne $targetProfileResolved) {
    $alreadyCallsLocalProfile = Select-String -Path $targetProfile -SimpleMatch -Pattern $sourceProfileResolved -Quiet

    if (-not $alreadyCallsLocalProfile) {
        Add-Content -Path $targetProfile -Value ""
        Add-Content -Path $targetProfile -Value ". '$sourceProfileResolved'"
    }
}

Write-Host "Copied starship.toml and profile.ps1 to $destinationDir"
