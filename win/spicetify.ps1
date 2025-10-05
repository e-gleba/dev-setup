Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$url = 'https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1'
$dst = Join-Path $env:TEMP 'spicetify-marketplace-install.ps1'

Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
Unblock-File $dst
& $dst
Remove-Item -Force $dst
