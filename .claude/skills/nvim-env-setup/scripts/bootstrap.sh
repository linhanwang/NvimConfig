#!/usr/bin/env bash
# Provision a machine for this NvChad-based Neovim config.
# Idempotent: re-running only fixes what is missing.
#
#   bash .claude/skills/nvim-env-setup/scripts/bootstrap.sh [--skip-system] [--verify-only]
#
# Env overrides: NVIM_VERSION, NODE_VERSION, MASON_PKGS

set -uo pipefail

NVIM_VERSION="${NVIM_VERSION:-v0.12.4}"
NODE_VERSION="${NODE_VERSION:-v24.18.0}"
# 0.12, not 0.11: aerial.nvim dropped <0.12 in dd80db7 (2026-05-14) and its
# setup() returns before creating :AerialToggle on older Neovim.
MIN_NVIM_MINOR=12
MIN_NODE_MAJOR=20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${NVIM_CONFIG_DIR:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SKIP_SYSTEM=0
VERIFY_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --skip-system) SKIP_SYSTEM=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if sudo -n true 2>/dev/null; then SUDO="sudo"
  elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; info "sudo may prompt for a password"
  fi
fi

OS="$(uname -s)"
case "$(uname -m)" in
  x86_64|amd64) NVIM_ARCH="x86_64"; NODE_ARCH="x64" ;;
  arm64|aarch64) NVIM_ARCH="arm64"; NODE_ARCH="arm64" ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

version_at_least() { # $1=have $2=want (major.minor)
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# ---------------------------------------------------------------- system deps
install_system_deps() {
  say "System dependencies"
  local missing=()
  for tool in git curl cc make unzip rg; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  # `rg` may be a shell function (e.g. a Claude Code shim); require a real binary
  if ! command -v rg >/dev/null 2>&1 || ! type -P rg >/dev/null 2>&1; then
    missing+=("rg")
  fi
  if [ ${#missing[@]} -eq 0 ]; then
    info "git, curl, cc, make, unzip, ripgrep present"
  elif [ "$OS" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew required on macOS: https://brew.sh"
    info "installing via brew: ripgrep"
    brew install ripgrep || true
    info "for a C compiler run: xcode-select --install"
  elif command -v apt-get >/dev/null 2>&1; then
    info "missing: ${missing[*]} — installing via apt"
    $SUDO apt-get update -qq
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      git curl build-essential unzip ripgrep python3-venv || die "apt-get install failed"
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y git curl gcc gcc-c++ make unzip ripgrep python3-virtualenv
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -S --needed --noconfirm git curl base-devel unzip ripgrep
  else
    die "install manually: ${missing[*]}"
  fi

  # Mason installs ruff/isort/ty into a python venv
  if command -v python3 >/dev/null 2>&1 && ! python3 -m venv --help >/dev/null 2>&1; then
    info "python3-venv missing — installing"
    command -v apt-get >/dev/null 2>&1 && $SUDO apt-get install -y -qq python3-venv
  fi
}

# -------------------------------------------------------------------- neovim
install_neovim() {
  say "Neovim (need >= 0.$MIN_NVIM_MINOR)"
  local have=""
  command -v nvim >/dev/null 2>&1 && have="$(nvim --version | head -1 | sed 's/^NVIM v//')"
  if [ -n "$have" ] && version_at_least "$have" "0.$MIN_NVIM_MINOR.0"; then
    info "nvim $have at $(command -v nvim) — ok"
    return
  fi
  [ -n "$have" ] && info "nvim $have is too old — installing $NVIM_VERSION"

  if [ "$OS" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew required on macOS"
    brew install neovim || die "brew install neovim failed"
    return
  fi

  local name="nvim-linux-${NVIM_ARCH}"
  local url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${name}.tar.gz"
  info "downloading $url"
  curl -fL --retry 3 -o "$WORK/nvim.tar.gz" "$url" || die "neovim download failed"
  $SUDO rm -rf "/opt/$name"
  $SUDO tar -C /opt -xzf "$WORK/nvim.tar.gz" || die "neovim extract failed"
  $SUDO ln -sf "/opt/$name/bin/nvim" /usr/local/bin/nvim
  hash -r
  info "installed $(nvim --version | head -1) -> /usr/local/bin/nvim"
  info "note: an older distro nvim may remain at /usr/bin/nvim; /usr/local/bin wins on a default PATH"
}

# ---------------------------------------------------------------------- node
install_node() {
  say "Node.js (need >= $MIN_NODE_MAJOR) + tree-sitter-cli"
  local have=""
  command -v node >/dev/null 2>&1 && have="$(node --version | sed 's/^v//')"
  if [ -n "$have" ] && version_at_least "$have" "${MIN_NODE_MAJOR}.0.0"; then
    info "node v$have at $(command -v node) — ok"
  elif [ "$OS" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew required on macOS"
    brew install node || die "brew install node failed"
  else
    local name="node-${NODE_VERSION}-linux-${NODE_ARCH}"
    local url="https://nodejs.org/dist/${NODE_VERSION}/${name}.tar.xz"
    info "downloading $url"
    curl -fL --retry 3 -o "$WORK/node.tar.xz" "$url" || die "node download failed"
    $SUDO rm -rf "/opt/$name"
    $SUDO tar -C /opt -xJf "$WORK/node.tar.xz" || die "node extract failed"
    for bin in node npm npx; do $SUDO ln -sf "/opt/$name/bin/$bin" "/usr/local/bin/$bin"; done
    hash -r
    info "installed node $(node --version), npm $(npm --version)"
  fi

  # keep global npm installs out of /opt (no sudo needed)
  mkdir -p "$HOME/.local/bin"
  npm config set prefix "$HOME/.local" >/dev/null 2>&1
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH"
       info "add \$HOME/.local/bin to your PATH in ~/.bashrc" ;;
  esac

  if command -v tree-sitter >/dev/null 2>&1; then
    info "tree-sitter $(tree-sitter --version | awk '{print $2}') — ok"
  else
    info "installing tree-sitter-cli"
    npm install -g tree-sitter-cli >/dev/null || die "npm install -g tree-sitter-cli failed"
    info "tree-sitter $(tree-sitter --version | awk '{print $2}')"
  fi
}

# ------------------------------------------------------------- neovim payload
sync_plugins() {
  say "Syncing lazy.nvim plugins"
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3
  # base46 writes the theme cache that init.lua dofile()s; a clean start proves it
  local errs
  errs="$(nvim --headless +qa 2>&1)"
  if [ -n "$errs" ]; then
    printf '%s\n' "$errs" | head -20
    die "nvim reports errors on startup"
  fi
  info "plugins synced, clean startup"
}

install_mason() {
  say "Installing Mason packages"
  nvim --headless -c "luafile $SCRIPT_DIR/mason_install.lua" 2>&1 | grep -Ev '^\s*$' | tail -25
}

install_parsers() {
  say "Installing treesitter parsers"
  local parsers
  parsers="$(nvim --headless -c 'lua
    local want = { lua = true, luadoc = true, printf = true, vim = true, vimdoc = true }
    local ok, spec = pcall(dofile, vim.fn.stdpath("config") .. "/lua/plugins/init.lua")
    if ok then
      for _, p in ipairs(spec) do
        if type(p) == "table" and type(p[1]) == "string" and p[1]:match("nvim%-treesitter$") then
          for _, name in ipairs((type(p.opts) == "table" and p.opts.ensure_installed) or {}) do want[name] = true end
        end
      end
    end
    io.stderr:write(table.concat(vim.tbl_keys(want), " "))' -c qa 2>&1)"
  info "parsers: $parsers"
  # `:TSInstallAll` is unusable here: NvChad's version calls the nvim-treesitter
  # `main`-branch API while this config pins `master`.
  # shellcheck disable=SC2086
  nvim --headless -c 'lua require("lazy").load{plugins={"nvim-treesitter"}}' \
    -c "TSInstallSync! $parsers" -c qa 2>&1 | tail -3
}

verify() {
  say "Verifying"
  local out="$WORK/verify.txt"
  # A pty is required: NvChad lazy-loads nvim-lspconfig on `User FilePost`,
  # which is gated on vim.g.ui_entered and never fires under plain --headless.
  if command -v script >/dev/null 2>&1; then
    if [ "$OS" = "Darwin" ]; then
      NVIM_VERIFY_OUT="$out" script -q /dev/null nvim -c "luafile $SCRIPT_DIR/verify.lua" >/dev/null 2>&1
    else
      NVIM_VERIFY_OUT="$out" script -qec "nvim -c 'luafile $SCRIPT_DIR/verify.lua'" /dev/null >/dev/null 2>&1
    fi
  else
    info "'script' not found — running without a pty; LSP checks will report FAIL spuriously"
    NVIM_VERIFY_OUT="$out" nvim --headless -c "luafile $SCRIPT_DIR/verify.lua" >/dev/null 2>&1
  fi
  [ -f "$out" ] || die "verification produced no output"
  cat "$out"
  grep -q "ALL CHECKS PASSED" "$out" || { echo; die "verification failed — see above"; }
}

# ---------------------------------------------------------------------- main
cd "$CONFIG_DIR" || die "config dir not found: $CONFIG_DIR"
[ -f "$CONFIG_DIR/init.lua" ] || die "no init.lua in $CONFIG_DIR — is this the nvim config repo?"
info "config: $CONFIG_DIR"
export PATH="/usr/local/bin:$PATH"

if [ "$VERIFY_ONLY" -eq 1 ]; then
  verify
  exit 0
fi

if [ "$SKIP_SYSTEM" -eq 0 ]; then
  install_system_deps
  install_neovim
  install_node
else
  say "Skipping system dependencies (--skip-system)"
fi

command -v nvim >/dev/null 2>&1 || die "nvim not on PATH"
sync_plugins
install_mason
install_parsers
verify

say "Done"
cat <<'EOF'
Remaining manual step: install a Nerd Font and select it in your terminal
emulator (the machine you type on, not necessarily this one):
https://www.nerdfonts.com/font-downloads — avoid the "Mono" variants.
EOF
