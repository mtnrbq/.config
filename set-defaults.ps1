param(
    [string]$SettingsPath
)

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

function ConvertFrom-JsonRelaxed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonText
    )

    # Remove // comments while preserving content inside quoted strings.
    $lines = $JsonText -split "`r?`n"
    $withoutComments = foreach ($line in $lines) {
        $inString = $false
        $escaped = $false
        $builder = New-Object System.Text.StringBuilder

        for ($i = 0; $i -lt $line.Length; $i++) {
            $ch = $line[$i]

            if (-not $escaped -and $ch -eq '"') {
                $inString = -not $inString
                [void]$builder.Append($ch)
                continue
            }

            if (-not $inString -and $ch -eq '/' -and ($i + 1) -lt $line.Length -and $line[$i + 1] -eq '/') {
                break
            }

            [void]$builder.Append($ch)

            if ($ch -eq '\\' -and -not $escaped) {
                $escaped = $true
            } else {
                $escaped = $false
            }
        }

        $builder.ToString()
    }

    $cleaned = ($withoutComments -join "`n")

    # Remove trailing commas before } or ] to support JSONC-like files.
    $cleaned = [regex]::Replace($cleaned, ',\s*(?=[}\]])', '')

    return $cleaned | ConvertFrom-Json -AsHashtable
}

function Get-MergeKey {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    if ($Item -isnot [System.Collections.IDictionary]) {
        return $null
    }

    if ($Item.Contains('guid') -and $null -ne $Item['guid']) {
        return "guid:$($Item['guid'])"
    }

    if ($Item.Contains('name') -and $null -ne $Item['name']) {
        return "name:$($Item['name'])"
    }

    if ($Item.Contains('id') -and $null -ne $Item['id']) {
        return "id:$($Item['id'])"
    }

    return $null
}

function Merge-Array {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$BaseArray,
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$OverlayArray
    )

    $mutableBase = New-Object System.Collections.ArrayList
    foreach ($item in $BaseArray) {
        $mutableBase.Add($item) | Out-Null
    }

    $allOverlayObjects = $true
    foreach ($item in $OverlayArray) {
        if ($item -isnot [System.Collections.IDictionary]) {
            $allOverlayObjects = $false
            break
        }
    }

    if ($allOverlayObjects) {
        $indexByKey = @{}

        for ($i = 0; $i -lt $mutableBase.Count; $i++) {
            $baseItem = $mutableBase[$i]
            $key = Get-MergeKey -Item $baseItem
            if ($null -ne $key) {
                $indexByKey[$key] = $i
            }
        }

        foreach ($overlayItem in $OverlayArray) {
            $key = Get-MergeKey -Item $overlayItem

            if ($null -ne $key -and $indexByKey.ContainsKey($key)) {
                $baseIndex = $indexByKey[$key]
                $baseItem = $mutableBase[$baseIndex]

                if ($baseItem -is [System.Collections.IDictionary] -and $overlayItem -is [System.Collections.IDictionary]) {
                    $mutableBase[$baseIndex] = Merge-Object -Base $baseItem -Overlay $overlayItem
                } else {
                    $mutableBase[$baseIndex] = $overlayItem
                }
            } else {
                $mutableBase.Add($overlayItem) | Out-Null
                if ($null -ne $key) {
                    $indexByKey[$key] = $mutableBase.Count - 1
                }
            }
        }

        return ,([object[]]$mutableBase.ToArray())
    }

    foreach ($item in $OverlayArray) {
        if ($mutableBase -notcontains $item) {
            $mutableBase.Add($item) | Out-Null
        }
    }

    return ,([object[]]$mutableBase.ToArray())
}

function Merge-Object {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Base,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Overlay
    )

    foreach ($key in $Overlay.Keys) {
        if (-not $Base.Contains($key)) {
            $Base[$key] = $Overlay[$key]
            continue
        }

        $baseValue = $Base[$key]
        $overlayValue = $Overlay[$key]

        if ($baseValue -is [System.Collections.IDictionary] -and $overlayValue -is [System.Collections.IDictionary]) {
            $Base[$key] = Merge-Object -Base $baseValue -Overlay $overlayValue
            continue
        }

        if ($baseValue -is [System.Collections.IList] -and $overlayValue -is [System.Collections.IList]) {
            $Base[$key] = Merge-Array -BaseArray $baseValue -OverlayArray $overlayValue
            continue
        }

        $Base[$key] = $overlayValue
    }

    return $Base
}

function Install-VSCodeExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CodeCli,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )

    $installedExtensions = & $CodeCli --profile $ProfileName --list-extensions
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not list VS Code extensions for profile '$ProfileName' using '$CodeCli'."
        exit 1
    }

    if ($installedExtensions -contains $ExtensionId) {
        Write-Host "VS Code extension already installed in '$ProfileName': $ExtensionId"
        return
    }

    & $CodeCli --profile $ProfileName --install-extension $ExtensionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install VS Code extension '$ExtensionId' in profile '$ProfileName'."
        exit 1
    }

    Write-Host "Installed VS Code extension in '$ProfileName': $ExtensionId"
}

$defaultsPath = Join-Path $PSScriptRoot 'terminal\defaults.json'
if (-not (Test-Path -Path $defaultsPath)) {
    Write-Error "Defaults file not found: $defaultsPath"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-Path -Path $candidate) {
            $SettingsPath = $candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        $SettingsPath = $candidatePaths[0]
    }
}

$settingsDir = Split-Path -Path $SettingsPath -Parent
if (-not (Test-Path -Path $settingsDir)) {
    New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -Path $SettingsPath)) {
    '{}' | Set-Content -Path $SettingsPath -Encoding utf8
}

$defaultsText = Get-Content -Path $defaultsPath -Raw
$settingsText = Get-Content -Path $SettingsPath -Raw

try {
    $defaultsObject = ConvertFrom-JsonRelaxed -JsonText $defaultsText
} catch {
    Write-Error "Could not parse defaults JSON at $defaultsPath. $($_.Exception.Message)"
    exit 1
}

try {
    $settingsObject = ConvertFrom-JsonRelaxed -JsonText $settingsText
} catch {
    Write-Error "Could not parse terminal settings JSON at $SettingsPath. $($_.Exception.Message)"
    exit 1
}

if ($null -eq $defaultsObject) {
    $defaultsObject = @{}
}

if ($null -eq $settingsObject) {
    $settingsObject = @{}
}

if ($settingsObject -isnot [System.Collections.IDictionary]) {
    Write-Error "Settings file must contain a JSON object at root: $SettingsPath"
    exit 1
}

if ($defaultsObject -isnot [System.Collections.IDictionary]) {
    Write-Error "Defaults file must contain a JSON object at root: $defaultsPath"
    exit 1
}

$merged = Merge-Object -Base $settingsObject -Overlay $defaultsObject

$backupPath = "$SettingsPath.bak"
Copy-Item -Path $SettingsPath -Destination $backupPath -Force

$jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
$jsonOptions.WriteIndented = $true
$jsonOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
$mergedJson = [System.Text.Json.JsonSerializer]::Serialize($merged, $jsonOptions)
$mergedJson | Set-Content -Path $SettingsPath -Encoding utf8

Write-Host "Merged $defaultsPath into $SettingsPath"
Write-Host "Backup written to $backupPath"

$vscodeDefaultsPath = Join-Path $PSScriptRoot 'vscode\settings.json'
if (-not (Test-Path -Path $vscodeDefaultsPath)) {
    Write-Error "VS Code defaults file not found: $vscodeDefaultsPath"
    exit 1
}

$vscodeSettingsPath = Join-Path $env:APPDATA 'Code\User\settings.json'
$vscodeSettingsDir = Split-Path -Path $vscodeSettingsPath -Parent

if (-not (Test-Path -Path $vscodeSettingsDir)) {
    New-Item -Path $vscodeSettingsDir -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -Path $vscodeSettingsPath)) {
    '{}' | Set-Content -Path $vscodeSettingsPath -Encoding utf8
}

$vscodeDefaultsText = Get-Content -Path $vscodeDefaultsPath -Raw
$vscodeSettingsText = Get-Content -Path $vscodeSettingsPath -Raw

try {
    $vscodeDefaultsObject = ConvertFrom-JsonRelaxed -JsonText $vscodeDefaultsText
} catch {
    Write-Error "Could not parse VS Code defaults JSON at $vscodeDefaultsPath. $($_.Exception.Message)"
    exit 1
}

try {
    $vscodeSettingsObject = ConvertFrom-JsonRelaxed -JsonText $vscodeSettingsText
} catch {
    Write-Error "Could not parse VS Code settings JSON at $vscodeSettingsPath. $($_.Exception.Message)"
    exit 1
}

if ($null -eq $vscodeDefaultsObject) {
    $vscodeDefaultsObject = @{}
}

if ($null -eq $vscodeSettingsObject) {
    $vscodeSettingsObject = @{}
}

if ($vscodeSettingsObject -isnot [System.Collections.IDictionary]) {
    Write-Error "VS Code settings file must contain a JSON object at root: $vscodeSettingsPath"
    exit 1
}

if ($vscodeDefaultsObject -isnot [System.Collections.IDictionary]) {
    Write-Error "VS Code defaults file must contain a JSON object at root: $vscodeDefaultsPath"
    exit 1
}

$vscodeDefaultsOverlay = $vscodeDefaultsObject

if ($vscodeDefaultsObject.Contains('defaults') -and $vscodeDefaultsObject['defaults'] -is [System.Collections.IDictionary]) {
    $vscodeDefaultsOverlay = $vscodeDefaultsObject['defaults']
}

$vscodeMerged = Merge-Object -Base $vscodeSettingsObject -Overlay $vscodeDefaultsOverlay

$vscodeBackupPath = "$vscodeSettingsPath.bak"
Copy-Item -Path $vscodeSettingsPath -Destination $vscodeBackupPath -Force

$vscodeMergedJson = [System.Text.Json.JsonSerializer]::Serialize($vscodeMerged, $jsonOptions)
$vscodeMergedJson | Set-Content -Path $vscodeSettingsPath -Encoding utf8

Write-Host "Merged $vscodeDefaultsPath into $vscodeSettingsPath"
Write-Host "Backup written to $vscodeBackupPath"

$codeCliCommand = Get-Command -Name code -ErrorAction SilentlyContinue
if ($null -eq $codeCliCommand) {
    Write-Warning "VS Code CLI 'code' was not found on PATH. Skipping theme/icon extension install."
    Write-Warning "In VS Code, run: Shell Command: Install 'code' command in PATH, then re-run this script."
    exit 0
}

$vscodeProfileName = 'Default'
$requiredExtensions = @(
    'Catppuccin.catppuccin-vsc',
    'Catppuccin.catppuccin-vsc-icons'
)

foreach ($extensionId in $requiredExtensions) {
    Install-VSCodeExtension -CodeCli $codeCliCommand.Source -ExtensionId $extensionId -ProfileName $vscodeProfileName
}
