#!/bin/sh
# 02-configure-pmbootstrap.sh
# Initializes pmbootstrap for Raspberry Pi 4 + PocketTerm35 + Phosh
# Writes config directly (without interactive prompts)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PMBOOTSTRAP_WORK="${PMBOOTSTRAP_WORK:-$HOME/.local/var/pmbootstrap-pocketterm35-rpi4-v10}"
PMBOOTSTRAP_APORTS="${PMBOOTSTRAP_APORTS:-$PMBOOTSTRAP_WORK/cache_git/pmaports}"

echo "==> 02: pmbootstrap init – RPi4, PocketTerm35, Phosh"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Error: pmbootstrap not found. Run 01-install-pmbootstrap.sh first."
    exit 1
fi

echo "==> Writing pmbootstrap configuration..."

mkdir -p "$HOME/.config"
cat > "$HOME/.config/pmbootstrap_v3.cfg" << CFGEOF
[pmbootstrap]
boot_size = 512
aports = $PMBOOTSTRAP_APORTS
build_pkgs_on_install = true
ccache_size = 5G
device = raspberry-pi4
extra_packages = none
extra_space = 0
hostname =
jobs = 8
kernel = rpi
keymap =
locale = en_US.UTF-8
ssh_key_glob = ~/.ssh/*.pub
ssh_keys = false
sudo_timer = false
systemd = default
timezone = GMT
ui = phosh
ui_extras = false
user = pmos
work = $PMBOOTSTRAP_WORK

[providers]

[mirrors]
alpine = http://dl-cdn.alpinelinux.org/alpine/
alpine_custom = none
pmaports = http://mirror.postmarketos.org/postmarketos/
pmaports_custom = none
systemd = http://mirror.postmarketos.org/postmarketos/extra-repos/systemd/
systemd_custom = none
CFGEOF

echo "==> Configuration written."
echo "==> Initializing pmbootstrap work directory..."
{
    # Defaults for work, pmaports, channel, vendor, and device;
    # explicit "y" for archived raspberry-pi4; defaults after that.
    printf '\n\n\n\n\ny\n'
    i=0
    while [ "$i" -lt 80 ]; do
        printf '\n'
        i=$((i + 1))
    done
} | "$PMBOOTSTRAP" init --shallow-initial-clone
"$PMBOOTSTRAP" config device
"$PMBOOTSTRAP" config ui
"$PMBOOTSTRAP" config user

echo ""
echo "==> 02: Done"
echo "    Next: ./03-prepare-dtbos.sh"
