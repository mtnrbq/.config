$packages = @(
	'Git.Git'
	'Microsoft.Powershell'
	'Vivaldi.Vivaldi'
	'Github.Copilot'
	'Github.cli'
	'gerardog.gsudo'
	'Microsoft.AzureCLI'
	'Microsoft.VisualStudioCode'
	'Starship.Starship'
    'CoreyButler.NVMforWindows'
    'astral-sh.uv'
)

foreach ($package in $packages) {
	Write-Host "Next package: $package"

	do {
		$input = Read-Host "Install $package? (yes/no/skip)"
		$normalized = $input.Trim().ToLowerInvariant()
	} while ($normalized -notin @('y', 'yes', 'n', 'no', 's', 'skip'))

	if ($normalized -in @('y', 'yes')) {
		Write-Host "Installing $package..."
		winget install --id $package -e
	} else {
		Write-Host "Skipping $package"
	}
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
	Write-Host 'Configuring GitHub CLI as git credential helper...'
	gh auth setup-git
} else {
	Write-Host 'gh not found; skipping git credential setup.'
}

if (Get-Command git -ErrorAction SilentlyContinue) {
	Write-Host 'Pointing git at tracked .githooks directory...'
	git -C $PSScriptRoot config core.hooksPath .githooks
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
	$globalVenv = Join-Path $env:USERPROFILE '.venvs\global'
	if (-not (Test-Path (Join-Path $globalVenv 'Scripts\Activate.ps1'))) {
		Write-Host 'Creating global uv venv at ~\.venvs\global...'
		uv venv $globalVenv
	} else {
		Write-Host 'Global uv venv already exists.'
	}
} else {
	Write-Host 'uv not found; skipping global venv creation.'
}

if (Get-Command nvm -ErrorAction SilentlyContinue) {
	$existingNode = Get-Command node -ErrorAction SilentlyContinue
	if ($existingNode) {
		Write-Host "Node already on PATH at $($existingNode.Source); skipping nvm install lts."
	} else {
		Write-Host 'Installing latest Node LTS via nvm...'
		nvm install lts
		# nvm-windows >= 1.2 supports the `lts` alias for `nvm use`.
		nvm use lts
	}
} else {
	Write-Host 'nvm not found; skipping Node LTS install. (Re-open the shell after installing NVMforWindows.)'
}

Write-Host 'Done.'
