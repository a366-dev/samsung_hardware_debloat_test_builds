#!/bin/bash
#
# This tool is designed to
# remove preinstalled bloatware
# from prism.img (CSC)
#

yellow='\033[93m'
red='\033[91m'
blue='\033[94m'
green='\033[92m'
end='\033[0m'
 
# Format: NAME:BLOCK SIZE:UUID
# By default all data except names
# are 0. They will be filled later
IMAGES_TO_PATCH=(
    'prism'
)

show_help() {
    echo "Usage: $0 -c 'CSC.img' -t 'temp_dir'"
    echo "  -c : CSC.img"
    echo "  -t : temporary directory"
    echo "Environment variables:"
    echo "  OUT_DIR : Custom output directory for the built prism.img"
    exit 1
}

while getopts "c:t:h" opt; do
    case "$opt" in
        c) CSC="${OPTARG}" ;;
        t) TEMP_DIR="${OPTARG}" ;;
        h|*) show_help ;;
    esac
done

if [[ -z "$CSC" || -z "$TEMP_DIR" ]]; then
    show_help
    exit 1
fi

OUT_DIR=$(realpath "${OUT_DIR:-$(pwd)}")

echo -e "${blue}[+] Extracting prism.img.lz4 from CSC${end}"
tar -xf "$CSC" -C "$TEMP_DIR" prism.img.lz4 &> /dev/null
if [[ $? != 0 ]]; then
    echo -e "${red}[-] Failed to extract the archive. Are u sure that is the correct path?${end}"
    exit 1
fi

echo -e "${blue}[+] Extracting prism.img from prism.img.lz4${end}"
lz4 -d "$TEMP_DIR/prism.img.lz4" "$TEMP_DIR/prism.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e "${red}[-] Failed to extract the archive${end}"
    exit 1
fi

echo -e "${blue}[+] Deleting prism.img.lz4 as unneeded${end}"
rm "$TEMP_DIR/prism.img.lz4"

echo -e "${blue}[+] Extracting prism.raw${end}"
simg2img "$TEMP_DIR/prism.img" "$TEMP_DIR/prism.raw" &> /dev/null

echo -e "${blue}[+] Deleting prism.img as unneeded${end}"
rm "$TEMP_DIR/prism.img"

mkdir "$TEMP_DIR/prism"

echo -e "${blue}[+] Mounting prism.raw${end}"
sudo mount -o loop,rw "$TEMP_DIR/prism.raw" "$TEMP_DIR/prism" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e "${red}[-] Failed to mount the image${end}"
    exit 1
fi

echo -e "${blue}[+] Removing preloaded stuff${end}"
sudo find "$TEMP_DIR/prism/preload" -type d -name "hidden_app" -prune -exec sudo rm -rf {} +

echo -e "${blue}[+] Unmounting prism.raw${end}"
sudo umount "$TEMP_DIR/prism"

img2simg "$TEMP_DIR/prism.raw" "$OUT_DIR/prism.img" &> /dev/null
