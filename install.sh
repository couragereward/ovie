#!/bin/bash
# ============================================================================
#  Ovie Programming Language v2.3.0 — Linux/macOS Installer
#
#  Uses the prebuilt binaries inside linux-x64/ (Linux) or
#  macos-arm64/ / macos-x64/ (macOS) from the cloned repo.
#  If the repo is not present it clones it automatically.
#
#  No Rust required. No release tarball needed.
#
#  Usage:
#    bash install.sh
# ============================================================================

set -e

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC}    $*"; }
info() { echo -e "  ${CYAN}[>>]${NC}    $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
fail() { echo -e "  ${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}  ============================================================================${NC}"
echo -e "${CYAN}  |              OVIE PROGRAMMING LANGUAGE v2.3.0                           |${NC}"
echo -e "${CYAN}  |              Publisher: Ovie Language Team  |  MIT License              |${NC}"
echo -e "${CYAN}  ============================================================================${NC}"
echo ""

OVIE_VERSION="2.3.0"
INSTALL_DIR="$HOME/.local/ovie"
BIN_DIR="$HOME/.local/bin"
GITHUB_REPO="https://github.com/southwarridev/ovie.git"

# ── Detect platform ───────────────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)  PLATFORM="linux" ;;
    Darwin*) PLATFORM="macos" ;;
    *)       fail "Unsupported OS: $OS. Use the Windows installer for Windows." ;;
esac

case "$ARCH" in
    x86_64)          ARCH_SLUG="x64" ;;
    arm64|aarch64)   ARCH_SLUG="arm64" ;;
    *)               ARCH_SLUG="x64" ;;   # best-effort fallback
esac

# linux-x64  /  macos-x64  /  macos-arm64
PLATFORM_DIR="${PLATFORM}-${ARCH_SLUG}"

echo "  Platform          : $OS ($ARCH)"
echo "  Install directory : $INSTALL_DIR"
echo "  Binaries added to : $BIN_DIR"
echo ""
read -rp "  Press ENTER to install or Ctrl+C to cancel..."
echo ""

# ── Step 1: Check git ────────────────────────────────────────────────────────
info "[1/5] Checking requirements..."
if ! command -v git >/dev/null 2>&1; then
    if [ "$PLATFORM" = "macos" ]; then
        fail "Git is not installed. Run: xcode-select --install"
    else
        fail "Git is not installed.
         Ubuntu/Debian : sudo apt install git
         Fedora        : sudo dnf install git
         Arch          : sudo pacman -S git"
    fi
fi
ok "Git found"

# ── Step 2: Find or clone the repo ───────────────────────────────────────────
info "[2/5] Locating Ovie source..."

REPO_ROOT=""
TEMP_CLONE=""

if [ -n "${BASH_SOURCE[0]}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

if [ -f "$SCRIPT_DIR/$PLATFORM_DIR/oviec" ]; then
    REPO_ROOT="$SCRIPT_DIR"
    ok "Using local repo at $REPO_ROOT  ($PLATFORM_DIR/)"
else
    TEMP_CLONE="/tmp/ovie-install-$$"
    info "   Cloning from GitHub (takes ~30 s on first run)..."
    git clone --depth 1 "$GITHUB_REPO" "$TEMP_CLONE" 2>&1 \
        | grep -E "Cloning|done\." || true
    REPO_ROOT="$TEMP_CLONE"
    ok "Cloned to $TEMP_CLONE"
fi

SRC="$REPO_ROOT/$PLATFORM_DIR"

# Fallback: if exact arch folder missing, try x64
if [ ! -f "$SRC/oviec" ] && [ "$ARCH_SLUG" = "arm64" ]; then
    warn "No $PLATFORM_DIR/ folder found, trying ${PLATFORM}-x64/ instead..."
    SRC="$REPO_ROOT/${PLATFORM}-x64"
fi

[ -f "$SRC/oviec" ] || fail "Cannot find oviec in $SRC. Please report this at https://github.com/southwarridev/ovie/issues"

ok "Using binaries from $SRC"

# ── Step 3: Create directories ───────────────────────────────────────────────
info "[3/5] Creating install directories..."
mkdir -p "$INSTALL_DIR" "$BIN_DIR" \
         "$INSTALL_DIR/std" "$INSTALL_DIR/examples" "$INSTALL_DIR/docs"
ok "Directories created"

# ── Step 4: Copy binaries and resources ──────────────────────────────────────
info "[4/5] Copying binaries..."

install -m 755 "$SRC/oviec" "$BIN_DIR/oviec"
ok "oviec installed"

if [ -f "$SRC/ovie" ]; then
    install -m 755 "$SRC/ovie" "$BIN_DIR/ovie"
else
    cp "$BIN_DIR/oviec" "$BIN_DIR/ovie"
    chmod +x "$BIN_DIR/ovie"
fi
ok "ovie installed"

info "   Copying standard library, examples and docs..."
[ -d "$SRC/std" ]      && cp -r "$SRC/std/."      "$INSTALL_DIR/std/"
[ -d "$SRC/examples" ] && cp -r "$SRC/examples/." "$INSTALL_DIR/examples/"
[ -d "$SRC/docs" ]     && cp -r "$SRC/docs/."     "$INSTALL_DIR/docs/"

for f in README.md LICENSE RELEASE_NOTES_v2.3.md ovie.png ovie.svg ovie.toml.template; do
    [ -f "$SRC/$f" ] && cp "$SRC/$f" "$INSTALL_DIR/"
done

STD_COUNT=$(find "$INSTALL_DIR/std"      -type f 2>/dev/null | wc -l | tr -d ' ')
EX_COUNT=$(find  "$INSTALL_DIR/examples" -name "*.ov" 2>/dev/null | wc -l | tr -d ' ')
ok "Standard library ($STD_COUNT files, 11 modules)"
ok "Examples ($EX_COUNT .ov files)"

# ── Step 5: Add to PATH ───────────────────────────────────────────────────────
info "[5/5] Adding $BIN_DIR to PATH..."

# Pick shell rc files — on macOS add to both zsh and bash profiles
if [ "$PLATFORM" = "macos" ]; then
    SHELL_RCS=("$HOME/.zshrc" "$HOME/.bash_profile")
elif [ -n "$ZSH_VERSION" ] || [ "$(basename "${SHELL:-bash}")" = "zsh" ]; then
    SHELL_RCS=("$HOME/.zshrc")
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RCS=("$HOME/.bashrc")
else
    SHELL_RCS=("$HOME/.profile")
fi

for rc in "${SHELL_RCS[@]}"; do
    if ! grep -q "$BIN_DIR" "$rc" 2>/dev/null; then
        {
            echo ""
            echo "# Ovie Programming Language"
            echo "export PATH=\"$BIN_DIR:\$PATH\""
        } >> "$rc"
        ok "Added to PATH in $rc"
    else
        ok "Already in PATH ($rc)"
    fi
done

export PATH="$BIN_DIR:$PATH"

# ── Cleanup temp clone ────────────────────────────────────────────────────────
if [ -n "$TEMP_CLONE" ] && [ -d "$TEMP_CLONE" ]; then
    rm -rf "$TEMP_CLONE"
fi

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
info "Verifying installation..."
VERSION_OUT=$("$BIN_DIR/oviec" --version 2>&1 | head -1)
ok "$VERSION_OUT"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ============================================================================${NC}"
echo -e "${GREEN}  |                    INSTALLATION COMPLETE!                               |${NC}"
echo -e "${GREEN}  ============================================================================${NC}"
echo ""
echo -e "  ${YELLOW}IMPORTANT:${NC} Reload your shell so PATH takes effect:"
for rc in "${SHELL_RCS[@]}"; do echo "    source $rc"; done
echo ""
echo "  Quick start:"
echo "    oviec --version               # Check version"
echo "    oviec --self-check            # Validate installation"
echo "    oviec run examples/hello.ov   # Run hello world"
echo "    oviec new my-project          # Create new project"
echo ""
echo "  Resources:"
echo "    Website : https://ovie.nashedy.io"
echo "    GitHub  : https://github.com/southwarridev/ovie"
echo "    Book    : https://southwarridev.github.io/ovie/docs/book/index.html"
echo "    Discord : https://discord.gg/AuF4ubMyE"
echo ""
