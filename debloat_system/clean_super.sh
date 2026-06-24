#!/bin/bash
#
# This script is designed for debloating
# and installing microG on Samsung devices
# The code is quite simple and straightforward,
# so I hope you won't have any trouble understanding
# it without documentation. Be careful and have fun!
#

usage() {
    echo -e ""
    echo -e "\e[3;33mUsage: $0 -m <\e[3;37mmodel\e[3;33m> -s <\e[3;37msdk\e[3;33m> -l <\e[3;37mlevel\e[3;33m> <\e[3;37mpath-to-FW-dir\e[3;33m>\e[0m"
    echo -e ""
    echo -e "\e[3;33mOptions:\e[0m"
    echo -e "  \e[3;37m-m, --model\e[0m       \e[3;36mSamsung model in 'SM-XXXXX' format\e[0m"
    echo -e "  \e[3;37m-s, --sdk\e[0m         \e[3;36mAndroid SDK version (for example: 26, 28, 29)\e[0m"
    echo -e "  \e[3;37m-l, --level\e[0m       \e[3;36mLevel of removal: (R)ecommended, (A)dvanced, (E)xpert\e[0m"
    echo -e "                     \e[3;36m(Each level includes the previous ones). Default:\e[0m \e[3;34mEXPERT"
    echo -e "  \e[3;37m-h, --help\e[0m        \e[3;36mShow this help message\e[0m"
    echo -e ""
    echo -e "\e[3;33mEnvironment variables:\e[0m"
    echo -e "  \e[3;37mOUT_DIR           \e[3;36mCustom output directory for the built images\e[0m"
    echo -e ""
    echo -e "\e[3;33mExample:\e[0m"
    echo -e "  \e[3;34m$0 -l a ~/firmwares/SM-AXXXX\e[0m"
    exit 1
}

if [[ $# -eq 0 ]]; then usage; fi

FW=""
MODE=""
SDK=""

typeset -l CLEAN_MODE
CLEAN_MODE='E'

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL=$(echo "$2" | tr '[:lower:]' '[:upper:]')
            shift 2
            ;;
        -s|--sdk)
            SDK="$2"
            shift 2
            ;;
        -l|--level)
            CLEAN_MODE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            FW=$(realpath "$1")
            shift
            ;;
    esac
done

if [[ -z "$FW" ]]; then
    echo -e "\e[1;31mError: FW path is missing\e[0m"
    exit 1
fi

if [[ ! "$MODEL" =~ ^SM-[[:alnum:]]+$ ]]; then
    echo -e "\e[1;31mError: invalid model\e[0m"
    exit 1
fi

if [[ ! "$SDK" =~ ^[[:digit:]]+$ ]]; then
    echo -e "\e[1;31mError: invalid SDK\e[0m"
    exit 1
fi

if [[ ! "$CLEAN_MODE" =~ ^[rae]$ ]]; then
    echo -e "\e[1;31mError: invalid clean mode\e[0m"
    exit 1
fi

SCRIPT_ROOT_DIR=$(realpath $(dirname "$0"))
PARENT_WORKING_DIRECTORY=$PWD
ROOT_DIR=$(realpath clean_super_$(date +%s))
OUT_DIR="${OUT_DIR:-$(pwd)/debloater_output}"

mkdir -p "$OUT_DIR"

AP=$(realpath $(find "$FW" -name "AP*" -type f))
CSC=$(realpath $(find "$FW" -name "CSC*" -type f))

if [[ -z "$AP" ]]; then
    echo -e "\e[1;31mError: AP path is missing\e[0m"
    exit 1
fi

if [[ -z "$CSC" ]]; then
    echo -e "\e[1;31mError: CSC path is missing\e[0m"
    exit 1
fi

CONFIG_FILES=('samsung_list.conf' 'google_list.conf')

# Format: NAME:BLOCK SIZE:UUID
# By default all data except names
# are 0. They will be filled later
IMAGES_TO_PATCH=(
    'product:0:0'
    'system:0:0'
    'system_ext:0:0'
)

echo -e '\e[3;36m[+] Enter admin password\e[0m'
sudo -v
if [[ $? -ne 0 ]]; then
    echo -e "\e[1;31mError: root access required\e[0m"
    exit 1
fi

while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
done &> /dev/null &

REQUIRED_COMMANDS=('rg' 'java' 'tar' 'lz4' 'simg2img' 'img2simg' 'lpunpack' 'lpmake' 'lpdump' 'fsck.erofs' 'xmlstarlet' 'aapt' 'aapt2' 'find' 'jq' 'attr')

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        echo -e "\e[1;31mError: command '$cmd' not found\e[0m"
        exit 1
    fi
done

mkdir "$ROOT_DIR"

echo -e '\e[3;36m[+] Downloading latest UAD-ng list\e[0m'
curl -Ls "https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/raw/refs/heads/main/resources/assets/uad_lists.json" -o "$SCRIPT_ROOT_DIR/UAD.ng"
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to get uad_lists.json\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Generating ROM permissions\e[0m'
bash "$SCRIPT_ROOT_DIR/dl-perm-list.sh" &> /dev/null

bash "$SCRIPT_ROOT_DIR/download_apps.sh" "$MODEL" "$SDK" "$ROOT_DIR" "$CLEAN_MODE"

OUT_DIR="$OUT_DIR" bash "$SCRIPT_ROOT_DIR/clean_prism.sh" -c "$CSC" -t "$ROOT_DIR"

# OUT_DIR="$ROOT_DIR" bash "$SCRIPT_ROOT_DIR/floris_overlay.sh" -p 1 -v "$SDK"
# if [[ $? != 0 ]]; then
#     echo -e '\e[1;31m[-] Failed to download android.jar\e[0m'
#     exit 1
# fi

echo -e '\e[3;36m[+] Extracting super.img.lz4 from AP\e[0m'
tar -xf "$AP" -C "$ROOT_DIR" super.img.lz4 &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive. Are u sure that is the correct path?\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Extracting super.img from super.img.lz4\e[0m'
lz4 -d "$ROOT_DIR/super.img.lz4" "$ROOT_DIR/super.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Deleting super.img.lz4 as unneeded\e[0m'
rm "$ROOT_DIR/super.img.lz4"

echo -e '\e[3;36m[+] Extracting super.raw\e[0m'
simg2img "$ROOT_DIR/super.img" "$ROOT_DIR/super.raw" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi
echo -e '\e[3;36m[+] Deleting super.img as unneeded\e[0m'
rm "$ROOT_DIR/super.img"

echo -e '\e[3;36m[+] Finally extracting super.raw\e[0m'
mkdir "$ROOT_DIR/super"
lpunpack "$ROOT_DIR/super.raw" "$ROOT_DIR/super" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Extracting images\e[0m'
for i in "${!IMAGES_TO_PATCH[@]}"; do
    IFS=':' read -r IMAGE BS UUID <<< "${IMAGES_TO_PATCH[$i]}"
    echo -e "   \e[3;36m[+] Processing $IMAGE\e[0m"
    mkdir "$ROOT_DIR/super/$IMAGE" "$ROOT_DIR/super/${IMAGE}_patch"

    DUMP_EROFS_DATA=$(dump.erofs "$ROOT_DIR/super/${IMAGE}_a.img")
    
    BS=$(echo "$DUMP_EROFS_DATA" | grep "Filesystem blocksize:" | awk '{print $3}')
    UUID=$(echo "$DUMP_EROFS_DATA" | grep "Filesystem UUID:" | awk '{print $3}')
    
    sudo mount -o loop "$ROOT_DIR/super/${IMAGE}_a.img" "$ROOT_DIR/super/$IMAGE" &> /dev/null
    if [[ $? != 0 ]]; then
        echo -e '\e[1;31m[-] Failed to mount the image\e[0m'
        exit 1
    fi
    
    sudo cp -aZ "$ROOT_DIR/super/$IMAGE/." "$ROOT_DIR/super/${IMAGE}_patch" &> /dev/null
    if [[ $? != 0 ]]; then
        echo -e '\e[1;31m[-] Failed to copy files\e[0m'
        exit 1
    fi

    sudo umount "$ROOT_DIR/super/$IMAGE" &> /dev/null
    if [[ $? != 0 ]]; then
        echo -e '\e[1;31m[-] Failed to unmount the image\e[0m'
        exit 1
    fi

    rmdir "$ROOT_DIR/super/$IMAGE" &> /dev/null
    mv "$ROOT_DIR/super/${IMAGE}_patch" "$ROOT_DIR/super/$IMAGE"

    IMAGES_TO_PATCH[$i]="$IMAGE:$BS:$UUID"
done

# mkdir "$ROOT_DIR/super/product" "$ROOT_DIR/super/system" "$ROOT_DIR/super/system_ext"
#
# echo -e '\e[3;36m[+] Extracting product_a.img\e[0m'
# fsck.erofs --extract="$ROOT_DIR/super/product" "$ROOT_DIR/super/product_a.img" &> /dev/null
# if [[ $? != 0 ]]; then
#     echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
#     exit 1
# fi
#
# echo -e '\e[3;36m[+] Extracting system_a.img\e[0m'
# fsck.erofs --extract="$ROOT_DIR/super/system" "$ROOT_DIR/super/system_a.img" &> /dev/null
# if [[ $? != 0 ]]; then
#     echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
#     exit 1
# fi
#
# echo -e '\e[3;36m[+] Extracting system_ext_a.img\e[0m'
# fsck.erofs --extract="$ROOT_DIR/super/sytem_ext" "$ROOT_DIR/super/system_ext_a.img" &> /dev/null
# if [[ $? != 0 ]]; then
#     echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
#     exit 1
# fi

# echo -e '\e[3;36m[+] Scanning for unchecked applications\e[0m'
#
# cd "$ROOT_DIR/super"
# sudo find product system/system system_ext -maxdepth 2 -path "*/app/*" -o -path "*/priv-app/*" -type d | sort > all.apps
#
# UNCHECKED_APPS=$(comm -23 all.apps "$SCRIPT_ROOT_DIR/checked.apps")
#
# cd $PARENT_WORKING_DIRECTORY
#
# if [[ -n "$UNCHECKED_APPS" ]]; then
#     for app in $UNCHECKED_APPS; do
#         echo -e "\n\e[31m[!] WARNING: New unverified app detected:\e[0m"
#         echo -e "----------------------------------------"
#         echo -e "\e[1;32m$app\e[0m"
#         echo -e "----------------------------------------"
#         echo -e "Action: (d)elete, (k)eep, (w)hat are u want, keep it and dont ask me again, or (s)kip and decide manually? [d/k/s]"
#         read -sn 1 action
#
#         case $action in
#             d)
#                 echo "[+] Deleting $app\e[0m"
#                 sudo rm -rf "$ROOT_DIR/super/$app"
#                 ;;
#             k)
#                 echo "[+] Whitelising $app\e[0m"
#                 echo "$app" >> "$SCRIPT_ROOT_DIR/checked.apps"
#                 sort -u -o "$SCRIPT_ROOT_DIR/checked.apps" "$SCRIPT_ROOT_DIR/checked.apps"
#                 ;;
#             w)
#                 break
#                 ;;
#             s)
#                 echo "\e[3;36m[+] Understood. Exiting\e[0m"
#                 exit 0
#         esac
#     done
# fi

echo -e "\e[3;36m[+] Removing preloaded stuff\e[0m"
IFS=$'\n' read -r -d '' -a PRELOADED_STUFF < <(find "$ROOT_DIR/super/product/preload" \
                                                  "$ROOT_DIR/super/system/system/preload" \
                                                  "$ROOT_DIR/super/system_ext/preload" \
                                             -mindepth 1 -maxdepth 1 -type d 2> /dev/null; printf '\0')
for PRELOADED_DIR in "${PRELOADED_STUFF[@]}"; do
    [[ -z "$PRELOADED_DIR" ]] && continue
    PRELOADED_DIR_NAME=$(basename "$PRELOADED_DIR")
    echo -e "  \e[3;32m[*] Removing $PRELOADED_DIR_NAME\e[0m"
    sudo rm -rf "$PRELOADED_DIR"
done

sudo bash "$SCRIPT_ROOT_DIR/uad.sh" -l $CLEAN_MODE "$ROOT_DIR/super"

add_selinux() {
    local path="$1"
    sudo find "$path" -exec sudo setfattr -hn security.selinux -v "u:object_r:system_file:s0" {} +
}

echo -e "\e[3;36m[+] Adding priveleged apps\e[0m"
CAPPS_PRIV=$(sudo find "$ROOT_DIR/capps/priv-app" -mindepth 1 -maxdepth 1 -type d)
for CAPP_PRIV in $CAPPS_PRIV; do
    [[ -z "$CAPP_PRIV" ]] && continue
    CAPP_PRIV_NAME=$(basename "$CAPP_PRIV")
    echo -e "   \e[3;36m[*] Adding $CAPP_PRIV_NAME\e[0m"
    sudo mv "$CAPP_PRIV" "$ROOT_DIR/super/product/priv-app"
    add_selinux "$ROOT_DIR/super/product/priv-app/$CAPP_PRIV_NAME"
done

echo -e "\e[3;36m[+] Adding priveleged apps XMLs\e[0m"
CAPPS_PRIV_PERMS=$(sudo find "$ROOT_DIR/capps/perms" -mindepth 1 -maxdepth 1 -name "privapp*")
for CAPP_PRIV_PERM in $CAPPS_PRIV_PERMS; do
    [[ -z "$CAPP_PRIV_PERM" ]] && continue
    CAPP_PRIV_PERM_NAME=$(basename "$CAPP_PRIV_PERM")
    echo -e "   \e[3;36m[*] Adding $CAPP_PRIV_PERM_NAME\e[0m"
    sudo mv "$CAPP_PRIV_PERM" "$ROOT_DIR/super/product/etc/permissions"
    add_selinux "$ROOT_DIR/super/product/etc/permissions/$CAPP_PRIV_PERM_NAME"
done
    
echo -e "\e[3;36m[+] Adding custom apps\e[0m"
CAPPS=$(sudo find "$ROOT_DIR/capps/preload" -mindepth 1 -maxdepth 1 -type d)
for CAPP in $CAPPS; do
    [[ -z "$CAPP" ]] && continue
    CAPP_NAME=$(basename "$CAPP")
    echo -e "   \e[3;36m[*] Packing $CAPP_NAME\e[0m"
    sudo gzip $(find $CAPP -mindepth 1 -maxdepth 1 -type f -name "*.apk" | head -n 1)
    sudo mv "$CAPP" "$ROOT_DIR/super/system/system/preload"
    add_selinux "$ROOT_DIR/super/system/system/preload/$CAPP_NAME"
done

echo -e "\e[3;36m[+] Adding custom apps XMLs\e[0m"
CAPPS_PERMS=$(sudo find "$ROOT_DIR/capps/perms" -mindepth 1 -maxdepth 1 -name "default*")
for CAPP_PERM in $CAPPS_PERMS; do
    [[ -z "$CAPP_PERM" ]] && continue
    CAPP_PERM_NAME=$(basename "$CAPP_PERM")
    echo -e "   \e[3;36m[*] Adding $CAPP_PERM_NAME\e[0m"
    sudo mv "$CAPP_PERM" "$ROOT_DIR/super/product/etc/default-permissions"
    add_selinux "$ROOT_DIR/super/product/etc/default-permissions/$CAPP_PERM_NAME"
done

echo -e "\e[3;36m[+] Adding (custom/priveleged) apps sysconfigs\e[0m"
ALL_SYSCFGS=$(sudo find "$ROOT_DIR/capps/perms" -mindepth 1 -maxdepth 1 -name "sysconfig*")
for SYSCFG in $ALL_SYSCFGS; do
    [[ -z "$SYSCFG" ]] && continue
    SYSCFG_NAME=$(basename "$SYSCFG")
    echo -e "   \e[3;36m[*] Adding $SYSCFG_NAME\e[0m"
    sudo mv "$SYSCFG" "$ROOT_DIR/super/product/etc/sysconfig"
    add_selinux "$ROOT_DIR/super/product/etc/sysconfig/$SYSCFG_NAME"
done

echo -e "\e[3;36m[+] Adding FlorisBoard to safe-mode-allow-list.xml\e[0m"
sudo xmlstarlet ed -L -s "/config" -t elem -n "package" $ROOT_DIR/super/system/system/etc/sysconfig/safe-mode-allow-list.xml
sudo xmlstarlet ed -L -a "/config/package[not(@name)]" -t attr -n "name" -v "dev.patrickgold.florisboard.beta" $ROOT_DIR/super/system/system/etc/sysconfig/safe-mode-allow-list.xml

echo -e "\e[3;36m[+] Adding FlorisBoard to broadcast_allowlist.xml\e[0m"
sudo xmlstarlet ed -L -u "//package[@name='com.samsung.android.honeyboard']/@name" -v "dev.patrickgold.florisboard.beta" $ROOT_DIR/super/system/system/etc/broadcast_allowlist.xml

echo -e "\e[3;36m[+] Deleting com.samsung.android.honeyboard from floating_feature.xml\e[0m"
sudo xmlstarlet ed -L -d "//SEC_FLOATING_FEATURE_SIP_CONFIG_PACKAGE_NAME" $ROOT_DIR/super/system/system/etc/floating_feature.xml

# echo -e "\e[3;36m[+] Building FlorisBoard overlay\e[0m"
# OUT_DIR="$ROOT_DIR" bash "$SCRIPT_ROOT_DIR/floris_overlay.sh" -p 2 -v "$SDK"
# sudo chown 0:0 "$ROOT_DIR/FlorisOverlay.apk" "$ROOT_DIR/config.xml"
#
# sudo mkdir -p "$ROOT_DIR/super/product/overlay/config"
# sudo mv "$ROOT_DIR/config.xml" "$ROOT_DIR/super/product/overlay/config/config.xml"
# add_selinux "$ROOT_DIR/super/product/overlay/config/config.xml"
#
# sudo mkdir -p "$ROOT_DIR/super/product/overlay"
# sudo mv "$ROOT_DIR/FlorisOverlay.apk" "$ROOT_DIR/super/product/overlay"
# add_selinux "$ROOT_DIR/super/product/overlay"

echo -e "\e[3;36m[+] Removing g00gle XMLs\e[0m"
sudo find "$ROOT_DIR/super/product/etc/permissions"                        \
          "$ROOT_DIR/super/product/etc/sysconfig"                          \
          "$ROOT_DIR/super/product/etc/default-permissions"                \
          "$ROOT_DIR/super/system/system/etc/permissions"                  \
          "$ROOT_DIR/super/system/system/etc/sysconfig"                    \
          -type f \( -name "*google*.xml" -o -name "*gms*.xml" \)          \
          -printf "  \033[3;32m[*] Removing %f\033[0m\n" -exec sudo rm -f {} +

echo -e "\e[3;36m[+] Packing FW back\e[0m"

for ENTRY in "${IMAGES_TO_PATCH[@]}"; do
    IFS=':' read -r IMAGE BS UUID <<< "$ENTRY"
    echo -e "   \e[3;36m[*] Packing $IMAGE.img\e[0m"
    sudo mkfs.erofs -T 1640995200 -b $BS -U $UUID "$ROOT_DIR/super/${IMAGE}_a.img" "$ROOT_DIR/super/$IMAGE" &> /dev/null
done

# echo -e "   \e[3;36m[*] Packing product.img\e[0m"
# mkfs.erofs -zlz4hc "$ROOT_DIR/super/product_a.img" "$ROOT_DIR/super/product" --all-root &> /dev/null
# echo -e "   \e[3;36m[*] Packing system.img\e[0m"
# mkfs.erofs -zlz4hc "$ROOT_DIR/super/system_a.img" "$ROOT_DIR/super/system" --all-root &> /dev/null
# echo -e "   \e[3;36m[*] Packing system_ext.img\e[0m"
# mkfs.erofs -zlz4hc "$ROOT_DIR/super/system_ext_a.img" "$ROOT_DIR/super/system_ext" --all-root &> /dev/null

echo -e '\e[3;36m[+] Generating lpmake command\e[0m'
LPMAKE_CMD="$(OUT_DIR="$OUT_DIR" bash "$SCRIPT_ROOT_DIR/gen_lpmake.sh" "$ROOT_DIR")"

echo -e "\e[3;36m[+] Converting all A images to sparse format\e[0m"
ALL_IMAGES=$(find "$ROOT_DIR/super" -maxdepth 1 -name "*_a.img")

for image in $ALL_IMAGES; do
    echo -e "  \e[3;36m[*] $(basename "$image")\e[0m"
    img2simg "$image" "${image}_simg" &> /dev/null
    mv -f "${image}_simg" "$image"
done

echo -e '\e[3;36m[+] Processing lpmake command\e[0m'
mkdir $ROOT_DIR/tmp
eval "$LPMAKE_CMD" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to pack the archive\e[0m'
    exit 1
fi

# echo -e '\e[3;36m[+] Packing flashable tar to your current directory\e[0m'
# tar -cvf "$PARENT_WORKING_DIRECTORY/super.tar" -C "$ROOT_DIR" super.img &> /dev/null

echo -e "\e[3;36m[+] Removing working directory\e[0m"
sudo rm -rf "$ROOT_DIR"

echo -e "\e[3;36m[+] Now you can flash them through fastbootd. The images are located in $OUT_DIR\e[0m"
