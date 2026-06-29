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

$scriptRoot = $PSScriptRoot
$scripts = @(
    'winget-base.ps1',
    'Copy-config.ps1',
    'install-fonts.ps1',
    'set-defaults.ps1'
)

for ($i = 0; $i -lt $scripts.Count; $i++) {
    $scriptName = $scripts[$i]
    $scriptPath = Join-Path $scriptRoot $scriptName

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Error "Missing script: $scriptPath"
        exit 1
    }

    Write-Host "[$($i + 1)/$($scripts.Count)] Running $scriptName..."

    try {
        & $scriptPath
    } catch {
        Write-Error "Script failed: $scriptName. $($_.Exception.Message)"
        exit 1
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Script exited with code ${LASTEXITCODE}: $scriptName"
        exit $LASTEXITCODE
    }
}

Write-Host 'All setup scripts completed successfully.'
