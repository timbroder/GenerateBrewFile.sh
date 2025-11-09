#!/usr/bin/env bash
set -euo pipefail

# macOS/Bash 3.2 compatible; no 'mapfile'

readonly VERSION="0.1.1"

BREWFILE="${BREWFILE:-$HOME/Brewfile}"
DESCRIBE="${DESCRIBE:-1}"
QUIET="${QUIET:-0}"
CLI_BREWFILE=""

usage() {
  cat <<'EOF'
Usage: GenerateBrewFile.sh [options]

Options:
  -f, --brewfile <path>             Write the generated Brewfile to <path>.
  -h, --help                        Show this help message and exit.
  -V, --version                     Print the GenerateBrewFile.sh version and exit.

Environment variables can still be used to configure behaviour. When both
BREWFILE is set and --brewfile is supplied, the command-line option takes
precedence.
EOF
}

log() { [ "$QUIET" = "1" ] || echo "[$(date +'%H:%M:%S')] $*"; }

install_brew() {
  log "Homebrew not found; attempting automatic installation ..."

  if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: Homebrew is required but automatic installation is only supported on macOS." >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: Homebrew is required but 'curl' is not available to download the installer." >&2
    exit 1
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Ensure the current shell session can locate the freshly installed brew
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /usr/local/Homebrew/bin/brew ]; then
    eval "$(/usr/local/Homebrew/bin/brew shellenv)"
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew installation did not succeed." >&2
    exit 1
  fi

  log "Homebrew installation complete."
}

require() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  case "$1" in
    brew)
      install_brew
      return 0
      ;;
    mas)
      require brew
      log "'mas' CLI not found; installing via Homebrew ..."
      if ! brew list mas >/dev/null 2>&1; then
        brew install mas
      fi
      if command -v mas >/dev/null 2>&1; then
        log "'mas' installation complete."
        return 0
      fi
      echo "Error: Unable to install 'mas' via Homebrew." >&2
      exit 1
      ;;
  esac

  echo "Error: '$1' is not installed or not on PATH." >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -f|--brewfile)
      if [ "$#" -lt 2 ]; then
        echo "Error: $1 requires a path argument." >&2
        usage >&2
        exit 1
      fi
      CLI_BREWFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -V|--version)
      echo "GenerateBrewFile.sh ${VERSION}"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Error: Unexpected positional argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  echo "Error: Unexpected positional arguments: $*" >&2
  usage >&2
  exit 1
fi

if [ -n "$CLI_BREWFILE" ]; then
  BREWFILE="$CLI_BREWFILE"
fi

require brew
require mas

log "Dumping Homebrew formulae/casks/taps to $BREWFILE ..."
dump_args=(bundle dump --force --file="$BREWFILE")
[ "$DESCRIBE" = "1" ] && dump_args+=(--describe)
brew "${dump_args[@]}"

# ----- Build MAS app name set (for skip logic) -----
MAS_AVAILABLE=0
MAS_NAMES=()
if command -v mas >/dev/null 2>&1; then
  if mas account 2>/dev/null | grep -q "@"; then
    MAS_AVAILABLE=1
    log "Appending Mac App Store apps (mas list) ..."
    {
      echo
      echo "# ------------------------------"
      echo "# Mac App Store apps (via mas)"
      echo "# ------------------------------"
      mas list | sed -E 's/^([0-9]+) (.+) \(.+\)$/mas \"\2\", id: \1/'
    } >> "$BREWFILE"

    # capture MAS app names (for skip logic)
    while IFS= read -r n; do
      [ -n "$n" ] && MAS_NAMES+=("$n")
    done < <(mas list | sed -E 's/^[0-9]+ (.+) \(.+\)$/\1/')
  else
    log "Warning: Could not verify MAS login, but continuing since mas list works."
    MAS_AVAILABLE=1
    # fallback — still add mas apps
    {
      echo
      echo "# ------------------------------"
      echo "# Mac App Store apps (via mas)"
      echo "# ------------------------------"
      mas list | sed -E 's/^([0-9]+) (.+) \(.+\)$/mas \"\2\", id: \1/'
    } >> "$BREWFILE"
  fi
else
  log "No 'mas' CLI detected; skipping Mac App Store apps."
  {
    echo
    echo "# ------------------------------"
    echo "# Mac App Store apps (skipped - 'mas' CLI not installed)"
    echo "# Install: brew install mas"
    echo "# ------------------------------"
  } >> "$BREWFILE"
fi

in_mas_names() {
  # exact string match on app bundle display name
  local x="$1" n
  for n in "${MAS_NAMES[@]:-}"; do
    [ "$n" = "$x" ] && return 0
  done
  return 1
}

log "Scanning /Applications and ~/Applications for manually installed apps ..."

# All .app bundle names
ALL_APPS=()
while IFS= read -r app; do
  [ -n "$app" ] && ALL_APPS+=("$app")
done < <(
  { find /Applications -maxdepth 1 -type d -name "*.app" 2>/dev/null
    find "$HOME/Applications" -maxdepth 1 -type d -name "*.app" 2>/dev/null; } \
  | sed 's#.*/##' | sed 's/\.app$//' | sort -fu
)

# Installed casks
INSTALLED_CASKS=()
while IFS= read -r c; do
  [ -n "$c" ] && INSTALLED_CASKS+=("$c")
done < <(brew list --cask --full-name 2>/dev/null || true)

is_installed_cask() {
  local needle="$1" c
  for c in "${INSTALLED_CASKS[@]:-}"; do
    [ "$c" = "$needle" ] && return 0
  done
  return 1
}

# Guess a cask token (stderr silenced to avoid noisy "No formulae..." lines)
guess_cask_for_app() {
  local app_name="$1"
  local guess first
  guess="$(echo "$app_name" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9+_.-')"

  if brew search --casks "^${guess}$" 2>/dev/null | grep -qx "$guess"; then
    echo "$guess"; return 0
  fi

  first="$(brew search --casks "$app_name" 2>/dev/null | head -n 1 || true)"
  if [ -n "$first" ]; then
    echo "$first"; return 0
  fi

  return 1
}

LIKELY_CASKS=()
MANUAL_ONLY=()

for app in "${ALL_APPS[@]:-}"; do
  # skip Apple system apps
  case "$app" in
    Safari|Mail|Calendar|Contacts|Messages|FaceTime|Music|TV|Photos|Preview|Notes|Reminders|Books|"App Store")
      continue ;;
  esac

  # NEW: if this app comes from MAS, skip cask guessing (already covered via mas)
  if [ "$MAS_AVAILABLE" = "1" ] && in_mas_names "$app"; then
    continue
  fi

  if cask_token="$(guess_cask_for_app "$app")"; then
    if ! is_installed_cask "$cask_token"; then
      LIKELY_CASKS+=("$app -> $cask_token")
    fi
  else
    MANUAL_ONLY+=("$app")
  fi
done

{
  echo
  echo "# ------------------------------"
  echo "# Suggestions for manually installed apps"
  echo "# ------------------------------"
  if [ "${#LIKELY_CASKS[@]:-0}" -gt 0 ]; then
    echo "# Likely available as casks (unmanaged right now). Consider adding lines like:"
    for pair in "${LIKELY_CASKS[@]}"; do
      token="${pair##*-> }"
      echo "#   cask \"$token\"   # $pair"
    done
  else
    echo "# No obvious cask matches were found for your app bundles."
  fi
  echo "#"
  echo "# Remaining apps that don't have an obvious cask:"
  if [ "${#MANUAL_ONLY[@]:-0}" -gt 0 ]; then
    for app in "${MANUAL_ONLY[@]}"; do
      echo "#   $app"
    done
  else
    echo "#   (none)"
  fi
} >> "$BREWFILE"

log "Done. Brewfile written to: $BREWFILE"
log "Validate with:  brew bundle check --file=\"$BREWFILE\""
