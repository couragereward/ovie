#Requires -Version 5.0
# ============================================================================
#  Ovie Programming Language v2.3.0 — Windows PowerShell Installer
#  Works by cloning the repo and copying the prebuilt windows-x64 binaries.
#  No Rust, no GitHub release zip needed.
# ============================================================================

param(
    [string]$InstallDir = "C:\Program Files\Ovie",
    [switch]$Force = $false
)

# ── helpers ──────────────────────────────────────────────────────────────────
function Write-Step   { param([string]$m) Write-Host "  [>>] $m" -ForegroundColor Cyan }
function Write-Ok     { param([string]$m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Fail   { param([string]$m) Write-Host "  [ERROR] $m" -ForegroundColor Red }
function Write-Warn   { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }

function Require-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]"Administrator")
    if (-not $isAdmin) {
        Write-Warn "Not running as Administrator — re-launching elevated..."
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

function Require-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail "Git is not installed. Download it from: https://git-scm.com/download/win"
        Write-Fail "Then re-run this installer."
        exit 1
    }
}

# ── banner ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ============================================================================" -ForegroundColor Cyan
Write-Host "  |                                                                          |" -ForegroundColor Cyan
Write-Host "  |              OVIE PROGRAMMING LANGUAGE v2.3.0                           |" -ForegroundColor Cyan
Write-Host "  |              Complete Module System - Full Package                       |" -ForegroundColor Cyan
Write-Host "  |              Publisher: Ovie Language Team  |  MIT License              |" -ForegroundColor Cyan
Write-Host "  |                                                                          |" -ForegroundColor Cyan
Write-Host "  ============================================================================" -ForegroundColor Cyan
Write-Host ""

# ── preflight ─────────────────────────────────────────────────────────────────
Require-Admin
Require-Git

$BinDir = "$InstallDir\bin"

Write-Host "  Install directory : $InstallDir" -ForegroundColor White
Write-Host "  Binaries          : $BinDir" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "  Press ENTER to install or type 'cancel' to exit"
if ($confirm -eq "cancel") { exit 0 }

Write-Host ""

try {
    # ── Step 1: find or clone the repo ───────────────────────────────────────
    Write-Step "[1/5] Locating Ovie source..."

    # Prefer: script is sitting inside the cloned repo already
    $RepoRoot = $null

    # Check if this script is inside a repo that has windows-x64\bin\oviec.exe
    $candidate = $PSScriptRoot
    if (Test-Path (Join-Path $candidate "windows-x64\bin\oviec.exe")) {
        $RepoRoot = $candidate
        Write-Ok "Using local repo at $RepoRoot"
    }

    # Otherwise clone fresh
    if (-not $RepoRoot) {
        $CloneTarget = "$env:TEMP\ovie-install-$(Get-Random)"
        Write-Step "   Cloning from GitHub (this takes ~30 seconds)..."
        git clone --depth 1 "https://github.com/southwarridev/ovie.git" $CloneTarget 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "git clone failed. Check your internet connection."
            exit 1
        }
        $RepoRoot = $CloneTarget
        Write-Ok "Cloned to $RepoRoot"
    }

    $Src = Join-Path $RepoRoot "windows-x64"

    # Sanity-check the source
    if (-not (Test-Path "$Src\bin\oviec.exe")) {
        Write-Fail "Cannot find windows-x64\bin\oviec.exe in the repo. The repo layout may have changed."
        exit 1
    }

    # ── Step 2: create directories ───────────────────────────────────────────
    Write-Step "[2/5] Creating install directories..."
    foreach ($d in @($InstallDir, $BinDir, "$InstallDir\std", "$InstallDir\examples", "$InstallDir\docs")) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    Write-Ok "Directories created"

    # ── Step 3: copy binaries ────────────────────────────────────────────────
    Write-Step "[3/5] Copying binaries..."

    Copy-Item "$Src\bin\oviec.exe" "$BinDir\oviec.exe" -Force
    Write-Ok "oviec.exe installed"

    # ovie.exe lives at windows-x64\ovie.exe (CLI wrapper)
    if (Test-Path "$Src\ovie.exe") {
        Copy-Item "$Src\ovie.exe" "$BinDir\ovie.exe" -Force
    } else {
        # Fallback: duplicate oviec as ovie
        Copy-Item "$BinDir\oviec.exe" "$BinDir\ovie.exe" -Force
    }
    Write-Ok "ovie.exe installed"

    # ── Step 4: copy stdlib, examples, docs ─────────────────────────────────
    Write-Step "[4/5] Copying standard library, examples and docs..."

    if (Test-Path "$Src\std")      { Copy-Item "$Src\std"      "$InstallDir\std"      -Recurse -Force }
    if (Test-Path "$Src\examples") { Copy-Item "$Src\examples" "$InstallDir\examples" -Recurse -Force }
    if (Test-Path "$Src\docs")     { Copy-Item "$Src\docs"     "$InstallDir\docs"     -Recurse -Force }

    # Root-level extras
    foreach ($f in @("README.md","LICENSE","RELEASE_NOTES_v2.3.md","ovie.png","ovie.svg","ovie.toml.template")) {
        $fp = Join-Path $Src $f
        if (Test-Path $fp) { Copy-Item $fp "$InstallDir\" -Force }
    }
    Write-Ok "Files copied"

    # ── Step 5: PATH ─────────────────────────────────────────────────────────
    Write-Step "[5/5] Adding $BinDir to system PATH..."
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$BinDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$BinDir", "Machine")
        $env:PATH = "$env:PATH;$BinDir"
        Write-Ok "Added to PATH"
    } else {
        Write-Ok "Already in PATH"
    }

    # ── Cleanup temp clone ────────────────────────────────────────────────────
    if ($RepoRoot -like "$env:TEMP\*") {
        Remove-Item $RepoRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ── Verify ───────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Step "Verifying..."
    $ver = & "$BinDir\oviec.exe" --version 2>&1 | Select-Object -First 1
    Write-Ok $ver

    # ── Done ─────────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  ============================================================================" -ForegroundColor Green
    Write-Host "  |                  INSTALLATION COMPLETE!                                 |" -ForegroundColor Green
    Write-Host "  ============================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  IMPORTANT: Restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Quick start:" -ForegroundColor Cyan
    Write-Host "    oviec --version              # Check version" -ForegroundColor White
    Write-Host "    oviec --self-check           # Validate installation" -ForegroundColor White
    Write-Host "    oviec run examples\hello.ov  # Run hello world" -ForegroundColor White
    Write-Host "    oviec new my-project         # Create new project" -ForegroundColor White
    Write-Host ""
    Write-Host "  Docs: https://southwarridev.github.io/ovie/docs/book/index.html" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Fail "Installation failed: $($_.Exception.Message)"
    exit 1
}

Write-Host "  Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
