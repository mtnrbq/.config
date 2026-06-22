Invoke-Expression (&starship init powershell)
$PSStyle.FileInfo.Directory = "`e[34;1m"

# >>> uv setup >>>
# Ensure uv's executable dir (Python shims + `uv tool` installs) is on PATH.
$uvLocalBin = Join-Path $env:USERPROFILE '.local\bin'
if ((Test-Path $uvLocalBin) -and (($env:PATH -split ';') -notcontains $uvLocalBin)) {
    $env:PATH = "$uvLocalBin;$env:PATH"
}

# Persistent global Python venv. Don't let venv activation rewrite the prompt
# (starship already surfaces the active env); we manage activation ourselves.
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'
$GlobalVenv = Join-Path $env:USERPROFILE '.venvs\global'
$GlobalVenvActivate = Join-Path $GlobalVenv 'Scripts\Activate.ps1'
function gpy {
    if (Test-Path $GlobalVenvActivate) { . $GlobalVenvActivate }
    else { Write-Warning "Global venv not found at $GlobalVenv" }
}

# Make the global venv the baseline: auto-activate it now, and whenever no venv is
# active (e.g. after you `deactivate` a repo's .venv) re-activate it on the next
# prompt. Repo venvs still take precedence while active; `uv run`/`uv sync` ignore
# activation entirely. Set $env:UV_NO_AUTO_GLOBAL=1 (via `uvoff`) to opt out.
$Global:__uvBasePrompt = (Get-Item Function:prompt).ScriptBlock
function global:prompt {
    $__uvExit = $LASTEXITCODE
    if (-not $env:VIRTUAL_ENV -and -not $env:UV_NO_AUTO_GLOBAL -and (Test-Path $GlobalVenvActivate)) {
        . $GlobalVenvActivate
        $global:LASTEXITCODE = $__uvExit
    }
    & $Global:__uvBasePrompt
}

# Leave the global venv and STAY out (disables auto-re-activation this session).
function uvoff {
    $env:UV_NO_AUTO_GLOBAL = '1'
    if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
}
# Re-enable auto-global and activate it now.
function uvon {
    Remove-Item Env:UV_NO_AUTO_GLOBAL -ErrorAction SilentlyContinue
    gpy
}
gpy
# <<< uv setup <<<