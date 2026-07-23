#!/bin/sh
# 06-flash-nvme.sh
# Flashes the built image to a connected SD card, USB drive, or NVMe drive

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"

echo "==========================================="
echo "  Flash PocketTerm35 Image to Block Device"
echo "==========================================="
echo ""

# ---- Select image ----
IMAGE=""
TARGET_DEV=""
if [ -n "$1" ]; then
    if [ -b "$1" ]; then
        TARGET_DEV="$1"
    else
        IMAGE="$1"
    fi
fi
if [ -n "$2" ]; then
    TARGET_DEV="$2"
fi

if [ -z "$IMAGE" ]; then
    IMAGE="$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)"
fi
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Error: No image found."
    echo "  Usage: $0 [path/to/image.img] [/dev/target]"
    echo "         $0 /dev/target"
    echo "  Or:    place a .img file in $IMAGE_DIR/"
    exit 1
fi
echo "Image: $IMAGE ($(du -h "$IMAGE" | cut -f1))"

# ---- List candidate block devices ----
echo ""
echo "Found candidate block devices:"
lsblk -d -o NAME,SIZE,MODEL,TRAN -e 2,11 2>/dev/null | grep -E 'sd|mmcblk|nvme' || echo "  (none found)"
echo ""

AVAILABLE_TARGETS=""
for dev in /dev/mmcblk0 /dev/mmcblk1 /dev/sd? /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1; do
    if [ -b "$dev" ]; then
        model="$(cat /sys/block/$(basename $dev)/device/model 2>/dev/null || echo "block device")"
        size="$(lsblk -dn -o SIZE "$dev" 2>/dev/null)"
        AVAILABLE_TARGETS="$AVAILABLE_TARGETS    $dev - $model ($size)\n"
    fi
done

if [ -z "$AVAILABLE_TARGETS" ] && [ -z "$TARGET_DEV" ]; then
    echo "ERROR: No candidate block device found."
    echo ""
    echo "Possible reasons:"
    echo "  - SD card, USB drive, or NVMe not connected / not detected"
    echo "  - No permission (run script with sudo)"
    exit 1
fi

echo "Available targets:"
printf "$AVAILABLE_TARGETS"
echo ""

# ---- Select target ----
if [ -z "$TARGET_DEV" ]; then
    if [ "$(printf "$AVAILABLE_TARGETS" | wc -l)" -eq 1 ]; then
        TARGET_DEV="$(printf "$AVAILABLE_TARGETS" | grep -o '/dev/\(mmcblk[0-9]\|sd[a-z]\|nvme[0-9]n[0-9]\)' | head -1)"
        echo "-> Single target: $TARGET_DEV"
    else
        echo "Please enter target device (e.g. /dev/mmcblk0, /dev/sdX, /dev/nvme0n1):"
        printf "> "
        read TARGET_DEV
    fi
fi

if [ ! -b "$TARGET_DEV" ]; then
    echo "ERROR: $TARGET_DEV is not a block device."
    exit 1
fi

# ---- Safety check ----
echo ""
echo "==========================================="
echo "  WARNING! ALL DATA ON $TARGET_DEV WILL BE ERASED!"
echo "==========================================="
echo "  Image:  $IMAGE"
echo "  Target: $TARGET_DEV"
echo "  Size:   $(lsblk -dn -o SIZE "$TARGET_DEV")"
echo ""
echo "  Type 'yes' to confirm: "
printf "> "
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# ---- Check if image fits on target ----
IMAGE_SIZE="$(stat -c%s "$IMAGE")"
TARGET_SIZE_BYTES="$(blockdev --getsize64 "$TARGET_DEV" 2>/dev/null || echo 0)"
if [ "$TARGET_SIZE_BYTES" -le 0 ]; then
    echo "ERROR: Could not determine target size for $TARGET_DEV"
    exit 1
fi

if [ "$IMAGE_SIZE" -gt "$TARGET_SIZE_BYTES" ]; then
    echo "ERROR: Image ($IMAGE_SIZE bytes) is larger than target ($TARGET_SIZE_BYTES bytes)"
    exit 1
fi

# ---- Flash ----
echo ""
echo "==> Flashing $IMAGE -> $TARGET_DEV ..."
echo "    This may take a few minutes."

START_TIME="$(date +%s)"

# Flash with dd
sudo dd if="$IMAGE" of="$TARGET_DEV" bs=4M status=progress conv=fsync

END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"

# sync
echo ""
echo "==> Syncing..."
sync

# ---- Re-read partition table ----
echo "==> Re-reading partition table..."
sudo partprobe "$TARGET_DEV" 2>/dev/null || sudo blockdev --rereadpt "$TARGET_DEV" 2>/dev/null || true

echo ""
echo "==========================================="
echo "  Done! Image flashed successfully!"
echo "==========================================="
echo "  Target:  $TARGET_DEV"
echo "  Image:   $(basename "$IMAGE")"
echo "  Time:    ${DURATION}s"
echo "  Speed:   $(( IMAGE_SIZE / 1048576 / (DURATION + 1) )) MB/s"
echo ""
echo "  Now insert into PocketTerm35 and power on:"
echo "  - After the first boot the root partition will be"
echo "    automatically expanded to the full target size"
echo "  - User: pmos"
echo "  - PIN:  5115"
echo "==========================================="
