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

Write-Host 'Done.'
