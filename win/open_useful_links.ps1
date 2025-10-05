Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$links = @(
    "https://rsload.net/soft/manager/8313-aida64-extreme-edition1.html",
    "https://rsload.net/soft/manager/23708-ablebits-ultimate-suite-for-excel.html",
    "https://rsload.net/soft/editor/39797-efficient-elements-for-presentations.html",
    "https://rsload.net/soft/editor/33771-pvs-studio.html",
    "https://rsload.net/soft/cleaner-disk/11198-ultimatedefrag.html",
    "https://rsload.net/soft/cleaner-disk/12953-partition-assistant.html",
    "https://rutracker.org/forum/viewtopic.php?t=6183097",
    "https://rutracker.org/forum/viewtopic.php?t=6178172",
    "https://rutracker.org/forum/viewtopic.php?t=6220259",
    "https://rutracker.org/forum/viewtopic.php?t=6454193",
    "https://clonezilla.org/downloads.php",
    "https://browser.yandex.by/"
)

$links | ForEach-Object { Start-Process $_ }

if (-not (Get-AppxPackage -Name Microsoft.WindowsStore)) {
  Start-Process 'https://github.com/m-jishnu/alt-app-installer'
}
