Invoke-Expression (& 'C:\Program Files\starship\bin\starship.exe' init powershell --print-full-init | Out-String)
$PSStyle.FileInfo.Directory = "`e[34;1m"