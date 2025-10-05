# Enable-WindowsDev.ps1
# Enables Windows 11 Developer Mode, WSL (default version 2), and Windows Sandbox (if supported).
# Idempotent. Safe to re-run. Requires elevation.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Run this script as Administrator."
  }
}

function Get-Win11 {
  $build = [Environment]::OSVersion.Version.Build
  [pscustomobject]@{
    Build = $build
    IsWin11 = ($build -ge 22000)
  }
}

function Test-SLAT {
  # Second-level address translation support (required for Sandbox; WSL2 benefits).
  # Does not depend on locale or external tools.
  try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 -Property SecondLevelAddressTranslationExtensions
    return [bool]$cpu.SecondLevelAddressTranslationExtensions
  } catch {
    return $false
  }
}

function Get-EditionId {
  (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionID
}

function Set-DeveloperMode {
  Write-Host "[devmode] Enabling Developer Mode..." -ForegroundColor Cyan

  $cvPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
  if (-not (Test-Path $cvPath)) { New-Item -Path $cvPath -Force | Out-Null }
  New-ItemProperty -Path $cvPath -Name 'AllowDevelopmentWithoutDevLicense' -PropertyType DWord -Value 1 -Force | Out-Null
  New-ItemProperty -Path $cvPath -Name 'AllowAllTrustedApps' -PropertyType DWord -Value 1 -Force | Out-Null

  # Also set policy keys to avoid conflicts with managed environments
  $polPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx'
  if (-not (Test-Path $polPath)) { New-Item -Path $polPath -Force | Out-Null }
  New-ItemProperty -Path $polPath -Name 'AllowDevelopmentWithoutDevLicense' -PropertyType DWord -Value 1 -Force | Out-Null
  New-ItemProperty -Path $polPath -Name 'AllowAllTrustedApps' -PropertyType DWord -Value 1 -Force | Out-Null

  Write-Host "[devmode] Developer Mode ON"
}

function Enable-FeatureIfNeeded {
  param(
    [Parameter(Mandatory=$true)][string] $Name
  )
  $state = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue
  if (-not $state) {
    Write-Host "[feature] $Name not found on this edition. Skipping." -ForegroundColor Yellow
    return [pscustomobject]@{ Enabled = $false; RestartNeeded = $false; Present = $false }
  }

  if ($state.State -eq 'Enabled') {
    Write-Host "[feature] $Name already enabled"
    return [pscustomobject]@{ Enabled = $true; RestartNeeded = $false; Present = $true }
  }

  Write-Host "[feature] Enabling $Name ..." -ForegroundColor Cyan
  $res = Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart -ErrorAction Stop
  $restart = ($res.RestartNeeded -eq $true)
  Write-Host "[feature] $Name enabled; restart_needed=$restart"
  return [pscustomobject]@{ Enabled = $true; RestartNeeded = $restart; Present = $true }
}

function Set-WSLDefaults {
  try {
    wsl.exe --set-default-version 2 | Out-Null
    Write-Host "[wsl] Default version set to 2"
  } catch {
    Write-Warning "[wsl] Could not set default version to 2 (likely pending reboot). Re-run after reboot."
  }
}

function Update-WSLKernel {
  try {
    wsl.exe --update | Out-Null
    Write-Host "[wsl] Kernel updated"
  } catch {
    Write-Warning "[wsl] Kernel update failed (offline or pending reboot). You can re-run: wsl --update"
  }
}

function Install-WSLDistroIfMissing {
  param(
    [string] $Distro = 'Fedora'
  )
  try {
    $installed = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "[wsl] Listing distros failed (likely pending reboot). Skipping install."
      return
    }
    if ([string]::IsNullOrWhiteSpace($installed)) {
      Write-Host "[wsl] No distros installed. Installing $Distro ..." -ForegroundColor Cyan
      & wsl.exe --install -d $Distro
      if ($LASTEXITCODE -eq 0) {
        Write-Host "[wsl] $Distro install initiated."
      } else {
        Write-Warning "[wsl] Install returned code $LASTEXITCODE. You can install manually after reboot: wsl --install -d $Distro"
      }
    } else {
      Write-Host "[wsl] Distro(s) already present: $installed"
    }
  } catch {
    Write-Warning "[wsl] Distro install failed: $($_.Exception.Message)"
  }
}

function Enable-WindowsDevStack {
  [CmdletBinding()]
  param(
    [switch] $AutoReboot,
    [string] $Distro = 'Fedora'
  )

  Assert-Admin

  $os = Get-Win11
  if (-not $os.IsWin11) {
    Write-Warning "This script targets Windows 11 (build >= 22000). Detected build: $($os.Build). Proceeding, but some operations may differ."
  }

  $slat = Test-SLAT
  if (-not $slat) {
    Write-Warning "CPU SLAT not detected. Windows Sandbox and smooth WSL2 may not work. Enable virtualization (Intel VT-x/AMD-V) in BIOS/UEFI."
  }

  Set-DeveloperMode

  $restartNeeded = $false

  # WSL stack
  $wsl = Enable-FeatureIfNeeded -Name 'Microsoft-Windows-Subsystem-Linux'
  $restartNeeded = $restartNeeded -or $wsl.RestartNeeded

  $vmp = Enable-FeatureIfNeeded -Name 'VirtualMachinePlatform'
  $restartNeeded = $restartNeeded -or $vmp.RestartNeeded

  # Sandbox (guard by edition)
  $edition = Get-EditionId
  $sandboxSupported = @('Professional','Enterprise','Education','ProfessionalWorkstation') -contains $edition
  if (-not $sandboxSupported) {
    Write-Host "[sandbox] Edition '$edition' doesn’t support Windows Sandbox. Skipping." -ForegroundColor Yellow
  } else {
    $sb = Enable-FeatureIfNeeded -Name 'Containers-DisposableClientVM'
    $restartNeeded = $restartNeeded -or $sb.RestartNeeded
  }

  if ($restartNeeded) {
    Write-Host "[system] One or more features require a restart." -ForegroundColor Yellow
    if ($AutoReboot) {
      Write-Host "[system] Rebooting now..." -ForegroundColor Cyan
      Restart-Computer -Force
      return
    } else {
      Write-Host "[system] Please reboot, then re-run this script to finalize WSL kernel update and distro setup."
      return
    }
  }

  # Finalize WSL bits (safe to attempt; will noop if already done)
  Set-WSLDefaults
  Update-WSLKernel
  Install-WSLDistroIfMissing -Distro $Distro

  Write-Host "[done] Developer Mode, WSL (default v2), and Sandbox (if supported) are configured."
}

# Example direct call:
# Enable-WindowsDevStack -AutoReboot -Distro 'Fedora'
