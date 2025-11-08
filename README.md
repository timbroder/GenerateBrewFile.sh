# GenerateBrewFile.sh

GenerateBrewFile.sh is a single-file Bash utility that builds a comprehensive `Brewfile` for your macOS machine. It combines the output of `brew bundle dump` with metadata about your Mac App Store purchases and locally installed `.app` bundles so that you have a complete, human-readable inventory of the software on your Mac.

## Features

* Dumps all installed Homebrew formulae, casks, and taps using `brew bundle dump`.
* Optionally includes inline descriptions for formulae/casks when `brew bundle dump --describe` is supported.
* Adds a Mac App Store section (via the [`mas`](https://github.com/mas-cli/mas) CLI) showing app names and IDs.
* Scans `/Applications` and `~/Applications` for manually installed `.app` bundles and suggests matching casks where available.
* Notes any remaining apps that do not have an obvious cask, helping you track manual install steps.
* Works with the stock macOS Bash 3.2 runtime (no `mapfile`, uses POSIX-friendly constructs).

## Prerequisites

| Requirement | Purpose |
|-------------|---------|
| macOS | The script depends on Homebrew and the macOS application bundle layout. |
| [Homebrew](https://brew.sh/) | Provides the `brew` command used to dump your environment. If `brew` is missing the script attempts a non-interactive installation and configures the current shell session to use it. |
| [`mas` CLI](https://github.com/mas-cli/mas) (optional) | Enables the Mac App Store section; without it the script records that MAS apps were skipped. When `mas` is missing the script installs it with Homebrew before proceeding. |

## Installation

Clone the repository (or copy the script) and make it executable:

```bash
git clone https://github.com/<your-org>/GenerateBrewFile.sh.git
cd GenerateBrewFile.sh
chmod +x GenerateBrewFile.sh
```

You can now run the script directly or move it somewhere on your `$PATH` (for example `~/bin`).

## Usage

From the repository root (or wherever the script lives), run:

```bash
./GenerateBrewFile.sh
```

By default this writes `~/Brewfile`, includes descriptions when supported, and prints progress messages. The script will:

0. Ensure that both `brew` and the `mas` CLI are available, installing them automatically when necessary.
1. Require that `brew` exists, then run `brew bundle dump --force --file "$HOME/Brewfile" --describe`.
2. If the `mas` CLI is installed and logged in, append your Mac App Store apps (`mas "Display Name", id: 123456789`).
3. Scan `/Applications` and `~/Applications` for `.app` bundles that do not already appear in your MAS list, skip obvious Apple system apps, and try to match each bundle to a Homebrew cask token.
4. Record suggested cask names (e.g., `#   cask "google-chrome"   # Google Chrome -> google-chrome`).
5. List any remaining `.app` bundles that could not be mapped to a cask so you can document manual installation steps.
6. Finish with a reminder to validate using `brew bundle check`.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BREWFILE` | `$HOME/Brewfile` | Path to write the generated Brewfile. |
| `DESCRIBE` | `1` | When set to `1` (default) the script adds `--describe` so formulae/casks include the Homebrew description text. Set to `0` to omit descriptions. |
| `QUIET` | `0` | Set to `1` to suppress log output (only errors will print). |

You can combine these for different scenarios:

```bash
# Generate into the current directory without descriptions
BREWFILE="$(pwd)/Brewfile" DESCRIBE=0 ./GenerateBrewFile.sh

# Run silently and output to a custom path
QUIET=1 BREWFILE="$HOME/Documents/work-mac.Brewfile" ./GenerateBrewFile.sh
```

### Types of applications captured

GenerateBrewFile.sh inventories multiple categories of software:

* **Homebrew formulae** – Core packages installed via `brew install`.
* **Homebrew casks** – GUI apps, fonts, and other binary artifacts installed via `brew install --cask`.
* **Homebrew taps** – Additional tap repositories required by the above packages.
* **Mac App Store apps** – Applications associated with your Apple ID, collected with the `mas` CLI.
* **Manually installed `.app` bundles** – Applications living in `/Applications` or `~/Applications` that are not otherwise tracked; the script suggests casks or flags them for manual follow-up.

## Example output excerpt

```text
# ------------------------------
# Mac App Store apps (via mas)
# ------------------------------
mas "Xcode", id: 497799835
mas "Things 3", id: 904280696

# ------------------------------
# Suggestions for manually installed apps
# ------------------------------
# Likely available as casks (unmanaged right now). Consider adding lines like:
#   cask "google-chrome"   # Google Chrome -> google-chrome
#   cask "spotify"         # Spotify -> spotify
#
# Remaining apps that don't have an obvious cask:
#   OmniGraffle
```

## Validation

After generating your Brewfile you can confirm that Homebrew can satisfy it:

```bash
brew bundle check --file="/path/to/Brewfile"
```

Resolve any missing dependencies, then commit the Brewfile to source control or store it alongside your personal backups.

## Troubleshooting

* **`Error: 'brew' is not installed or not on PATH.`** – Install Homebrew from [brew.sh](https://brew.sh/) and ensure `brew` is available in your shell.
* **`mas` section is missing.** – Install `mas` (`brew install mas`) and log in (`mas account`) before running the script.
* **Applications missing from suggestions.** – Some bundles have unconventional names. Re-run the script periodically to refresh suggestions, or manually add the relevant `cask` or notes to your Brewfile.

## Contributing

Issues and pull requests are welcome! Please open an issue describing the improvement you have in mind, or submit a PR directly.

## License

This project is licensed under the terms of the [MIT License](LICENSE).

---

_Vibe coded using ChatGPT._
