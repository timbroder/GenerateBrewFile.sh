#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="GenerateBrewFile.sh"
DEFAULT_REPO_SLUG="timbroder/GenerateBrewFile.sh"
DEFAULT_BRANCH="main"

print_usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Fetches the latest GenerateBrewFile.sh from GitHub and installs it into a directory on your PATH.

Options:
  --install-dir <path>   Destination directory for the script. Defaults to the first writable path
                         chosen from: /opt/homebrew/bin, /usr/local/bin, $HOME/.local/bin, $HOME/bin.
  --repo <owner/repo>    GitHub repository slug containing GenerateBrewFile.sh (default: timbroder/GenerateBrewFile.sh).
  --branch <name>        Git branch/tag to download from (default: main).
  --force                Overwrite an existing installation without prompting.
  -h, --help             Show this help message and exit.

Environment variables:
  RAW_BASE_URL           Overrides the base URL used to download GenerateBrewFile.sh.

Example (install straight from GitHub):
  curl -fsSL https://raw.githubusercontent.com/timbroder/GenerateBrewFile.sh/main/install.sh | \
    bash -s -- --repo timbroder/GenerateBrewFile.sh --branch main
USAGE
}

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command '$1' not found. Please install it and re-run."
  fi
}

pick_install_dir() {
  local candidates=("/opt/homebrew/bin" "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin")
  local dir
  for dir in "${candidates[@]}"; do
    if [[ -d $dir && -w $dir ]]; then
      printf '%s' "$dir"
      return 0
    fi
    if [[ ! -d $dir ]]; then
      if mkdir -p "$dir" 2>/dev/null; then
        printf '%s' "$dir"
        return 0
      fi
    fi
  done
  return 1
}

confirm_overwrite() {
  local path=$1
  local force=$2
  if [[ ! -e $path || $force -eq 1 ]]; then
    return 0
  fi
  printf '%s already exists. Overwrite? [y/N] ' "$path" >&2
  read -r reply
  [[ $reply == "y" || $reply == "Y" ]]
}

main() {
  local install_dir=""
  local repo_slug="$DEFAULT_REPO_SLUG"
  local branch="$DEFAULT_BRANCH"
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-dir)
        [[ $# -lt 2 ]] && fail "--install-dir requires a path argument"
        install_dir="$2"
        shift 2
        ;;
      --repo)
        [[ $# -lt 2 ]] && fail "--repo requires an argument"
        repo_slug="$2"
        shift 2
        ;;
      --branch)
        [[ $# -lt 2 ]] && fail "--branch requires an argument"
        branch="$2"
        shift 2
        ;;
      --force)
        force=1
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
  done

  ensure_command curl

  if [[ -z $install_dir ]]; then
    install_dir=$(pick_install_dir) || fail "Could not determine an install directory. Use --install-dir to specify one."
  else
    mkdir -p "$install_dir"
  fi

  if [[ ! -w $install_dir ]]; then
    fail "Install directory '$install_dir' is not writable."
  fi

  local base_url="${RAW_BASE_URL:-"https://raw.githubusercontent.com/${repo_slug}/${branch}"}"
  local source_url="${base_url}/${SCRIPT_NAME}"
  local target_path="$install_dir/$SCRIPT_NAME"

  if ! confirm_overwrite "$target_path" "$force"; then
    say "Aborting install."
    exit 1
  fi

  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  say "Downloading ${SCRIPT_NAME} from ${source_url}"
  if ! curl -fsSL "$source_url" -o "$tmp"; then
    fail "Failed to download ${SCRIPT_NAME} from ${source_url}"
  fi

  if command -v install >/dev/null 2>&1; then
    install -m 0755 "$tmp" "$target_path"
  else
    cp "$tmp" "$target_path"
    chmod 0755 "$target_path"
  fi

  say "Installed ${SCRIPT_NAME} to ${target_path}"

  if ! command -v "$SCRIPT_NAME" >/dev/null 2>&1; then
    case ":$PATH:" in
      *:"$install_dir":*) ;;
      *)
        say "Note: ${install_dir} is not on your PATH. Add it to use ${SCRIPT_NAME} globally."
        ;;
    esac
  fi
}

main "$@"
