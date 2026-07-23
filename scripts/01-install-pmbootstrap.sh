#!/bin/sh
# 01-install-pmbootstrap.sh
# Installs pmbootstrap and all dependencies for the postmarketOS build

set -e

echo "==> 01: Installing dependencies and pmbootstrap"

# 1. System dependencies
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git python3 python3-pip openssl xz-utils \
                        coreutils dosfstools e2fsprogs util-linux curl wget \
                        kpartx procps
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed git python python-pip openssl xz \
                          coreutils dosfstools e2fsprogs util-linux curl wget \
                          multipath-tools procps-ng
elif command -v apk >/dev/null 2>&1; then
    sudo apk add git python3 py3-pip openssl xz coreutils \
                  dosfstools e2fsprogs util-linux curl wget \
                  multipath-tools procps
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git python3 python3-pip openssl xz \
                        coreutils dosfstools e2fsprogs util-linux curl wget \
                        kpartx procps-ng
else
    echo "Warning: No known package manager found."
    echo "Please install: git python3 openssl xz-utils coreutils dosfstools e2fsprogs curl wget kpartx procps"
fi

# 2. pmbootstrap from Git (recommended for the latest version)
echo "==> Cloning pmbootstrap..."
if [ ! -d "$HOME/pmbootstrap" ]; then
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap"
else
    echo "pmbootstrap already cloned, pulling..."
    cd "$HOME/pmbootstrap" && git pull
fi

PATCH_FILE="$HOME/pmbootstrap/pmb/install/partition.py"
if [ -f "$PATCH_FILE" ] && ! grep -q "Docker Desktop manual mknod" "$PATCH_FILE"; then
    echo "==> Patching pmbootstrap loop partition scan for Docker Desktop..."
    python3 - "$PATCH_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

text = text.replace(
    "import pmb.helpers.file\n",
    "import pmb.helpers.file\nimport pmb.helpers.run\n",
)

old_plain = (
    '        source = Path(f"{partition_prefix}{i}")\n'
    "        pmb.helpers.file.wait_until_exists(source)\n"
)
old_scan = (
    '        source = Path(f"{partition_prefix}{i}")\n'
    '        # Docker Desktop loop partition scan can lag behind partprobe.\n'
    '        if not source.exists() and str(disk).startswith("/dev/loop"):\n'
    '            logging.info(f"Refreshing partition table for {disk}")\n'
    '            pmb.helpers.run.root(["partprobe", str(disk)], check=False)\n'
    '            pmb.helpers.run.root(["partx", "-u", str(disk)], check=False)\n'
    '            pmb.helpers.run.root(["partx", "-a", str(disk)], check=False)\n'
    "        pmb.helpers.file.wait_until_exists(source)\n"
)
new = (
    '        source = Path(f"{partition_prefix}{i}")\n'
    '        # Docker Desktop manual mknod: loop partition nodes can lag behind partprobe.\n'
    '        if not source.exists() and str(disk).startswith("/dev/loop"):\n'
    '            logging.info(f"Refreshing partition table for {disk}")\n'
    '            pmb.helpers.run.root(["partprobe", str(disk)], check=False)\n'
    '            pmb.helpers.run.root(["partx", "-u", str(disk)], check=False)\n'
    '            pmb.helpers.run.root(["partx", "-a", str(disk)], check=False)\n'
    '            sys_dev = Path("/sys/block") / disk.name / source.name / "dev"\n'
    '            if not source.exists() and sys_dev.exists():\n'
    '                major, minor = sys_dev.read_text().strip().split(":")\n'
    '                pmb.helpers.run.root(["mknod", str(source), "b", major, minor], check=False)\n'
    "        pmb.helpers.file.wait_until_exists(source)\n"
)
if old_scan in text:
    text = text.replace(old_scan, new)
else:
    text = text.replace(old_plain, new)

path.write_text(text)
PY
fi

# 3. Symlink in ~/.local/bin/
mkdir -p "$HOME/.local/bin"
if [ ! -L "$HOME/.local/bin/pmbootstrap" ]; then
    ln -sf "$HOME/pmbootstrap/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
fi

# 4. Ensure PATH is set
case :$PATH: in
    *:$HOME/.local/bin:*) ;;
    *)
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "  -> ~/.local/bin added to PATH (please run 'source ~/.profile')"
        ;;
esac

# 5. Verify
echo "==> pmbootstrap version:"
"$HOME/.local/bin/pmbootstrap" --version

echo "==> 01: Done – pmbootstrap is ready."
echo "    Next: source ~/.profile && ./02-configure-pmbootstrap.sh"
