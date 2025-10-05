# windows_dev_setup.ps1
# minimal Windows bootstrap using Scoop primarily, no Cygwin, optional VS, with Chocolatey as fallback

[CmdletBinding()]
param(
    [switch]$install_visual_studio = $false,
    [ValidateSet('Community','BuildTools','Enterprise','Professional')]
    [string]$visual_studio_edition = 'Community',
    [switch]$install_ghidra = $true
)

function is-admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function ensure-executionpolicy {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force | Out-Null
    } catch {
        Write-Warning "Could not set ExecutionPolicy for CurrentUser. Continuing..."
    }
}

function ensure-scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Scoop (user scope)..." -ForegroundColor Cyan
        # Scoop prefers user installs; do not run as admin for this part
        $profileWasAdmin = is-admin
        if ($profileWasAdmin) {
            Write-Warning "Scoop installs best without elevation. Proceeding anyway; Scoop will still install to your user profile."
        }
        iwr -useb get.scoop.sh | iex
    } else {
        Write-Host "Scoop already installed." -ForegroundColor Green
    }
}

function add-scoop-buckets {
    $buckets = @('main','extras','versions','nerd-fonts')
    foreach ($b in $buckets) {
        $exists = (scoop bucket list) -match ("^\s*{0}\s*$" -f [regex]::Escape($b))
        if (-not $exists) {
            Write-Host "Adding Scoop bucket: $b" -ForegroundColor Cyan
            scoop bucket add $b | Out-Null
        }
    }
}

function ensure-choco {
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey (fallback only)..." -ForegroundColor Cyan
        # Official Chocolatey bootstrap
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey already installed." -ForegroundColor Green
    }
}

function install-scoop-package {
    param(
        [Parameter(Mandatory=$true)][string]$name
    )
    try {
        Write-Host "scoop install $name" -ForegroundColor Yellow
        scoop install $name --global:$false | Tee-Object -FilePath "$env:USERPROFILE\scoop_installation.log" -Append
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function install-choco-package {
    param(
        [Parameter(Mandatory=$true)][string]$name
    )
    try {
        Write-Host "choco install $name -y" -ForegroundColor Yellow
        choco install $name -y | Tee-Object -FilePath "$env:USERPROFILE\choco_installation.log" -Append
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function install-scoop-list {
    param(
        [Parameter(Mandatory=$true)][string[]]$packages
    )
    $failed = @()
    $i = 0
    $total = $packages.Count
    foreach ($p in $packages) {
        $i++
        Write-Progress -Activity "Installing $p ($i/$total)" -PercentComplete (($i/$total)*100)
        if (-not (install-scoop-package -name $p)) {
            $failed += $p
        }
    }
    Write-Progress -Activity "Scoop installs complete" -Completed
    return $failed
}

function rust-toolchains-setup {
    # Ensure rustup is available (installed via Scoop)
    if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
        Write-Error "rustup not found. Ensure 'rustup' installed via Scoop."
        return
    }
    Write-Host "Configuring Rust toolchains via rustup..." -ForegroundColor Cyan

    # Core Rust toolchains: stable-msvc (Windows MSVC), stable-gnu (MinGW)
    # Install both so you can choose per-project; default to MSVC if Visual Studio installed; otherwise GNU.
    $msvcDefault = $false
    if ($script:install_visual_studio -and (is-admin)) { $msvcDefault = $true }

    rustup toolchain install stable-msvc
    rustup toolchain install stable-gnu

    if ($msvcDefault) {
        rustup default stable-msvc
    } else {
        rustup default stable-gnu
    }

    rustup component add rustfmt clippy
}

function install-visualstudio {
    param(
        [ValidateSet('Community','BuildTools','Enterprise','Professional')]
        [string]$edition = 'Community'
    )
    if (-not (is-admin)) {
        Write-Error "Visual Studio installation requires Administrator. Re-run with elevated PowerShell or skip VS."
        return $false
    }

    # Use winget to install Visual Studio as recommended for MSVC workflows.
    # Community IDE or BuildTools (headless compiler toolchain).
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Error "winget not found. Install App Installer from Microsoft Store, or install VS manually."
        return $false
    }

    $id = switch ($edition) {
        'Community'    { 'Microsoft.VisualStudio.2022.Community' }
        'BuildTools'   { 'Microsoft.VisualStudio.2022.BuildTools' }
        'Enterprise'   { 'Microsoft.VisualStudio.2022.Enterprise' }
        'Professional' { 'Microsoft.VisualStudio.2022.Professional' }
    }

    Write-Host "Installing Visual Studio $edition via winget..." -ForegroundColor Cyan
    # Minimal workloads for C++ and desktop dev; adjust as needed
    $workloads = @(
        '--add Microsoft.VisualStudio.Workload.NativeDesktop',
        '--add Microsoft.VisualStudio.Workload.ManagedDesktop',
        '--add Microsoft.VisualStudio.Workload.Universal'
    ) -join ' '

    $args = @(
        'install','--id', $id,'-e','--accept-package-agreements','--accept-source-agreements','--silent','--override',
        "`"$workloads --includeRecommended`""
    )

    & winget @args
    return $LASTEXITCODE -eq 0
}

# -------------------------
# Main
# -------------------------
Write-Host "Minimal Windows setup using Scoop, Rust, and dev tools..." -ForegroundColor Cyan
ensure-executionpolicy

# 1) Scoop setup
ensure-scoop
add-scoop-buckets

# 2) Base packages via Scoop
# Do NOT include 'obsidian' and DO NOT install 'cygwin'
# Add dev CLI tools you like (rg, fzf, hyperfine, etc), llvm/clang, tracy, joplin
$base_scoop = @(
    'git',
    '7zip',
    'neovim',
    'vim',
    'clink',
    'cmake',
    'ninja',
    'python',
    'nodejs-lts',
    'wget',
    'curl',
    'aria2',

    'ripgrep',
    'fzf',
    'hyperfine',
    'bat',
    'fd',
    'eza',
    'sd',
    'delta',
    'bottom',
    'procs',
    'duf',
    'dust',
    'jq',
    'zoxide',

    'rustup',
    'rust-analyzer',
    'uutils-coreutils',

    'llvm',
    'mingw',

    'joplin',
    'windows-terminal',
    'everything',
    'winmerge',
    'mpv',
    'qbittorrent',
    'syncthing',

    'nmap',
    'wireshark',
    'processhacker',
    'imhex',
    'cpu-z',
    'powertoys',
    'systeminformer',
    'cheat-engine',
    'ghidra',
    'JetBrainsMono-NF',
    'tracy',

    '0xProto-NF',
    'ack',
    'age',
    'agg',
    'android-clt',
    'android-studio',
    'ansicon',
    'apktool',
    'asar7z',
    'ast-grep',
    'audacity',
    'bleachbit',
    'btop',
    'bulk-crap-uninstaller',
    'cacert',
    'ccache',
    'chromium',
    'clion',
    'cloc',
    'contour',
    'cppcheck',
    'crystaldiskmark',
    'dark',
    'dbeaver',
    'depends',
    'deskflow',
    'diffutils',
    'discord',
    'docker',
    'docker-compose',
    'dolphin',
    'doublecmd',
    'doxygen',
    'easy-context-menu',
    'exiftool',
    'ffmpeg',
    'filelight',
    'findutils',
    'FiraCode-NF',
    'gcc',
    'ghostwriter',
    'gimp',
    'git-lfs',
    'godot',
    'gpg4win',
    'gpu-z',
    'gradle',
    'graphviz',
    'handbrake',
    'hwinfo',
    'imagemagick',
    'inkscape',
    'innounp',
    'iperf3',
    'just',
    'kdenlive',
    'kdiff3',
    'latex',
    'lazygit',
    'libreoffice',
    'lua-for-windows',
    'lz4',
    'make',
    'marktext',
    'msys2',
    'nodejs',
    'nomacs',
    'obs-studio',
    'openjdk',
    'openjdk17',
    'openssl',
    'pandoc',
    'pe-bear',
    'peazip',
    'perl',
    'pkg-config',
    'plantuml',
    'postman',
    'python311',
    'qemu',
    'qt-creator',
    'radare2',
    'sampler',
    'scrcpy',
    'sharex',
    'shfmt',
    'simplewall',
    'speedcrunch',
    'speedtest-cli',
    'starship',
    'steam',
    'sumatrapdf',
    'sysinternals',
    'systeminformer-nightly',
    'temurin21-jdk',
    'tldr',
    'tokei',
    'ugrep',
    'unzip',
    'vcpkg',
    'vcredist2022',
    'vimtutor',
    'vlc',
    'vulkan',
    'wezterm',
    'winaero-tweaker',
    'wiztree',
    'x64dbg',
    'yazi',
    'yt-dlp',
    'zig'
)

$all_scoop = $base_scoop

$failed_scoop = install-scoop-list -packages $all_scoop
if ($failed_scoop.Count -gt 0) {
    Write-Warning "Scoop failed for: $($failed_scoop -join ', ')"
}

# 3) Rust toolchains and components with rustup
rust-toolchains-setup

# 4) Install Chocolatey as fallback and for packages not in Scoop
ensure-choco

# 5) Fallback installs via Chocolatey (if any failed on Scoop)
if ($failed_scoop.Count -gt 0) {
    Write-Host "Attempting Chocolatey fallback for failed packages..." -ForegroundColor Cyan
    $failed_after_choco = @()
    foreach ($pkg in $failed_scoop) {
        if (-not (install-choco-package -name $pkg)) {
            $failed_after_choco += $pkg
        }
    }
    if ($failed_after_choco.Count -gt 0) {
        Write-Warning "Still failed after Chocolatey: $($failed_after_choco -join ', ')"
    } else {
        Write-Host "All previously failed packages installed via Chocolatey." -ForegroundColor Green
    }
}

# 6) Optional: install Visual Studio (MSVC toolchain support)
if ($install_visual_studio) {
    if (install-visualstudio -edition $visual_studio_edition) {
        Write-Host "Visual Studio $visual_studio_edition installed." -ForegroundColor Green
        # Prefer MSVC by default now that VS is present
        if (Get-Command rustup -ErrorAction SilentlyContinue) {
            rustup default stable-msvc
        }
    } else {
        Write-Warning "Visual Studio installation failed or skipped."
    }
}

# 7) Final updates and cleanup
Write-Host "Updating Scoop and cleaning old versions..." -ForegroundColor Cyan
scoop update *
scoop cleanup *

Write-Host "Setup complete. Open a new terminal session to ensure shims and PATH are in effect." -ForegroundColor Green
