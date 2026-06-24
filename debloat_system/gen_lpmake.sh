#!/bin/bash
#
# This tool is designed to build
# lpmake command according to
# lpdump. Do not use it manually,
# this script will be called
# by the main bash file
#

if [[ $# != 1 ]]; then
    echo "Usage: $0 <path-to-tmpdir>"
    exit 1
fi

SUPER_ROOT=$(realpath "$1")
OUT_DIR="${OUT_DIR:-$(pwd)}"

DATA=$(lpdump "$SUPER_ROOT/super.raw")
COMMAND="lpmake "

METADATA_SIZE=$(echo "$DATA" | rg -e "Metadata max size: (\d*)" -or '$1')
METADATA_SLOTS=$(echo "$DATA" | rg -e "Metadata slot count: (\d*)" -or '$1')
DEVICE_SIZE=$(echo "$DATA" | grep -A 50 "Block device table:" | grep -m 1 "Size:" | awk {'print $2'})

COMMAND="TMPDIR=$SUPER_ROOT/tmp $COMMAND --metadata-size $METADATA_SIZE --metadata-slots $METADATA_SLOTS --super-name super --device super:$DEVICE_SIZE "

while read -r line; do
    if [[ $line =~ Name:\ (.*) ]]; then
        GROUP_NAME="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ Maximum\ size:\ ([0-9]+) ]]; then
        GROUP_SIZE="${BASH_REMATCH[1]}"
        if [[ $GROUP_NAME != "default" && $GROUP_SIZE -ne 0 ]]; then
            COMMAND="$COMMAND --group $GROUP_NAME:$GROUP_SIZE"
        fi
    fi
done < <(echo "$DATA" | sed -n '/Group table:/,/^[A-Z].*:/ { /^[A-Z].*:/!p }')

while read -r line; do
    if [[ $line =~ Name:\ (.*) ]]; then
        PARTITION_NAME="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ Group:\ (.*) ]]; then
        PARTITION_GROUP="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ Attributes:\ (.*) ]]; then
        PARTITION_ATTRS="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ Extents: ]]; then
        IMG_PATH="$SUPER_ROOT/super/$PARTITION_NAME.img"
        if [[ -f $IMG_PATH && "$PARTITION_NAME" != *"_b" ]]; then
            PARTITION_SIZE=$(stat -c%s "$IMG_PATH")
            PARTITION_SIZE=$((($PARTITION_SIZE + 4095) / 4096 * 4096))
            COMMAND="$COMMAND --partition $PARTITION_NAME:$PARTITION_ATTRS:$PARTITION_SIZE:$PARTITION_GROUP --image $PARTITION_NAME=\"$IMG_PATH\""
        else
            COMMAND="$COMMAND --partition $PARTITION_NAME:$PARTITION_ATTRS:0:$PARTITION_GROUP"
        fi
    fi
done < <(echo "$DATA" | sed -n '/Partition table:/,/^[A-Z].*:/ { /^[A-Z].*:/!p }')

COMMAND="$COMMAND --sparse --output=\"$OUT_DIR/super.img\""

echo $COMMAND
