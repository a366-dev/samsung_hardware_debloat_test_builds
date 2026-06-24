#!/bin/bash
#
# This tool is designed to
# post install microG+
#

# ==============================================================================
# TERMINAL COLORS FOR FORMATTED OUTPUT (ANSI ESCAPE SEQUENCES)
# ==============================================================================
italic='\033[3m'
light_grey='\033[3;37m'
yellow='\033[93m'
red='\033[91m'
blue='\033[94m'
green='\033[92m'
cyan='\033[36m'
end='\033[0m'

usage() {
    echo -e ""
    echo -e "${yellow}Usage: $0${end}"
    echo -e ""
    echo -e "${yellow}Environment variables:${end}"
    echo -e "  ${light_grey}TMP_DIR           ${cyan}Custom temp directory for downloading neccessary files${end}"
    echo -e "${yellow}Example:${end}"
    echo -e "  ${italic}${blue}TMP_DIR=tmp $0${end}"
}

if [[ $# -gt 0 ]]; then usage; fi

TMP_DIR=$(realpath "${TMP_DIR:-$(pwd)/microG_plus_temp_dir}")
REQUIRED_COMMANDS=('rg' 'jq' 'adb')

mkdir -p $TMP_DIR

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        echo -e "${red}Error: command '$cmd' not found${end}"
        exit 1
    fi
done

invalid_selection() {
    echo -e "${red}[-] Invalid selection${end}"
    exit 1
}

# ==============================================================================
# UNIVERSAL FUNCTION TO DOWNLOAD LATEST ASSETS FROM GITHUB RELEASES
# ==============================================================================
download_from_github() {
    local REPO="$1"
    local MODULE_NAME="$2"
    local REGEX_MASK="$3"     # mask for link search
    
    echo -e "${cyan}[+] Downloading latest $MODULE_NAME${end}"
    
    local GITHUB_API=$(curl -L -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases" 2>/dev/null | jq '.[0]')
    
    if [[ $? -ne 0 || -z "$GITHUB_API" || "$GITHUB_API" == 'null' ]]; then
        echo -e "${red}[-] Failed to get latest release of $MODULE_NAME${end}"
        exit 1
    fi

    local DOWNLOAD_URL=$(echo "$GITHUB_API" | rg -e "\"browser_download_url\": \"($REGEX_MASK)\"" -or '$1')

    if [[ -z "$DOWNLOAD_URL" ]]; then
        echo -e "${red}[-] Could not find matching pattern for $MODULE_NAME${end}"
        exit 1
    fi

    curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/$MODULE_NAME"
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}[-] Failed to download $MODULE_NAME${end}"
        exit 1
    fi
}

# ==============================================================================
# MENU SELECTION: KERNELSU VARIANT & BUILD TYPE
# ==============================================================================
clear
echo -e "${yellow}=== KernelSU Suite Setup ===${end}"
echo -e "What would you like to download and install on the device?"
echo -e "  ${green}1)${end} Official KernelSU"
echo -e "  ${green}2)${end} KernelSU Next"
echo -e "  ${green}3)${end} WildKSU"
echo -e "  ${green}4)${end} Nothing (Manager already installed, download modules only)"
read -p "Your choice (1-4): " KSU_SELECTION

INSTALL_KSU=false
KSU_REPO=""
KSU_NAME=""
KSU_MASK=""

if [[ "$KSU_SELECTION" =~ ^[1-3]$ ]]; then
    INSTALL_KSU=true
    IS_SPOOFED=false

    if [[ "$KSU_SELECTION" =~ ^[2-3]$ ]]; then
        echo -e ""
        echo -e "${yellow}Which build type do you need?${end}"
        echo -e "  ${green}1)${end} Regular build"
        echo -e "  ${green}2)${end} Spoofed build (with built-in integrity bypass)"
        read -p "Your choice (1-2): " SPOOF_SELECTION
        [[ ! "$SPOOF_SELECTION" =~ ^[1-2]$ ]] && invalid_selection
        [[ "$SPOOF_SELECTION" == "2" ]] && IS_SPOOFED=true
    fi
    
    case $KSU_SELECTION in
        1)
            echo -e "${light_grey}[~] Selected: Official KernelSU${end}"
            KSU_REPO="tiann/KernelSU"
            KSU_NAME="KernelSU.apk"
            KSU_MASK="https://.*KernelSU.*-release\.apk"
            ;;
        2)
            KSU_REPO="KernelSU-Next/KernelSU-Next"
            if [[ "$SPOOF_SELECTION" == "2" ]]; then
                echo -e "${light_grey}[~] Selected: KernelSU Next (Spoofed)${end}"
                KSU_NAME="KernelSU-Next_spoofed.apk"
                KSU_MASK="https://.*KernelSU_Next.*-spoofed.*-release\.apk"
            else
                echo -e "${light_grey}[~] Selected: Regular KernelSU Next${end}"
                KSU_NAME="KernelSU-Next.apk"
                KSU_MASK="https://.*KernelSU_Next[^-]*-release\.apk"
            fi
            ;;
        3)
            KSU_REPO="WildKernels/Wild_KSU"
            if [[ "$SPOOF_SELECTION" == "2" ]]; then
                echo -e "${light_grey}[~] Selected: WildKSU (Spoofed)${end}"
                KSU_NAME="Wild_KSU_spoofed.apk"
                KSU_MASK="https://.*Wild_KSU_Spoofed.*\.apk"
            else
                echo -e "${light_grey}[~] Selected: Regular WildKSU${end}"
                KSU_NAME="Wild_KSU.apk"
                KSU_MASK="https://.*Wild_KSU_v.*\.apk"
            fi
            ;;
    esac
elif [[ "$KSU_SELECTION" == "4" ]]; then
    echo -e "${light_grey}[~] Manager is skipped. Downloading microG+ base modules only${end}"
else
    invalid_selection
fi

# ==============================================================================
# DOWNLOADING NECCESSARY COMPONENTS FROM GITHUB
# ==============================================================================
$INSTALL_KSU && download_from_github "$KSU_REPO" "$KSU_NAME" "$KSU_MASK"

# Modules installation
download_from_github "Hybrid-Mount/meta-hybrid_mount" "meta-hybrid_mount.zip" "https://.*Hybrid-Mount-[^a-zA-Z]*\.zip"
download_from_github "JingMatrix/NeoZygisk"           "NeoZygisk.zip"         "https://.*NeoZygisk.*-release\.zip"
download_from_github "JingMatrix/Vector"              "Vector.zip"            "https://.*Vector.*-Release.zip"
download_from_github "MeowDump/Integrity-Box"         "Integrity-Box.zip"     "https://.*Integrity-Box.*\.zip"
download_from_github "JingMatrix/TEESimulator"        "TEESimulator.zip"      "https://.*TEESimulator.*-Release.zip"

# ==============================================================================
# INSTRUCTIONS FOR DEVELOPER OPTIONS & INITIAL WAIT
# ==============================================================================
clear
echo -e "${yellow}=== Action Required: Enable USB Debugging ===${end}"
echo -e "Please follow these steps on your device right now:"
echo -e ""
echo -e "  1) Open ${cyan}Settings${end} on your phone."
echo -e "  2) Scroll down and go to ${cyan}About phone${end} -> ${cyan}Software information${end}."
echo -e "  3) Find ${cyan}Build number${end} and tap on it rapidly ${green}7 times${end}."
echo -e "     *(Enter your PIN/Password if prompted to unlock Developer options)*"
echo -e "  4) Go back to the main Settings menu, scroll to the bottom, and open ${cyan}Developer options${end}."
echo -e "  5) Find and enable the ${cyan}USB debugging${end} toggle."
echo -e "  6) Connect your phone to the PC using a USB cable."
echo -e ""
echo -e "${yellow}==================================================${end}"
read -p "Once the cable is plugged and debugging is enabled, press any key... "

# ==============================================================================
# CONNECTING VIA ADB & TRIGGERING THE PROMPT
# ==============================================================================
echo -e "\n${cyan}[*] Connecting to device via ADB...${end}"
echo -e "${cyan}[*] LOOK AT YOUR PHONE SCREEN NOW! An authorization prompt should appear${end}"
echo -e "${red}    !!! ATTENTION !!!${end}"
echo -e "${red}    Make sure to check ${green}\"Always allow from this computer\"${red} FIRST, then press ${green}Allow${red}${end}"

adb wait-for-device

# ==============================================================================
# DOUBLE CHECK FOR "ALWAYS ALLOW" (Now it's perfectly on time)
# ==============================================================================
while true; do
    echo -e ""
    echo -e "${red}[?] VERY IMPORTANT DOUBLE CHECK:${end}"
    echo -e "    Did you check ${green}\"Always allow from this computer\"${end} before pressing Allow on your phone?"
    read -p "Type 'Y' if you checked the box, or 'N' if you forgot and need to re-plug (y/n): " CONFIRM_ALLOW
    
    if [[ "$CONFIRM_ALLOW" =~ ^[Yy]$ ]]; then
        echo -e "${green}[+] Excellent! Proceeding to permission checks...${end}"
        break
    elif [[ "$CONFIRM_ALLOW" =~ ^[Nn]$ ]]; then
        echo -e "${yellow}[*] To fix this: Unplug the USB cable, plug it back in, and look for the prompt again${end}"
        read -p "Press any key once you have re-plugged and checked the \"Always allow\" box... "
    else
        echo -e "${red}[-] Invalid choice. Please type 'y' or 'n'${end}"
    fi
done

# ==============================================================================
# INSTALLING KERNELSU MANAGER
# ==============================================================================
if [[ "$INSTALL_KSU" = true ]]; then
    echo -e "\n${cyan}[+] Installing $KSU_NAME...${end}"
    
    if adb install -r "$TMP_DIR/$KSU_NAME" &> /dev/null; then
        echo -e "${green}[+] $KSU_NAME successfully installed!${end}"
    else
        echo -e "${red}[-] Failed to install $KSU_NAME. Please check if the file is corrupted or device space is full${end}"
        exit 1
    fi
fi

# ==============================================================================
# WAITING FOR ROOT PERMISSIONS IN ADB SHELL (UID 2000 -> UID 0)
# ==============================================================================
echo -e "\n${yellow}=== Action Required: Grant Root Access to ADB Shell ===${end}"
echo -e "To install the modules quietly, the script needs temporary Root privileges."
echo -e "You can safely disable this permission after the script finishes."
echo -e ""
echo -e "Please follow these steps on your phone right now:"
echo -e "  1) Open the newly installed ${cyan}KernelSU Manager${end} app."
echo -e "  2) Go to the ${cyan}Superuser${end} tab (the shield icon at the bottom)."
echo -e "  3) Find ${green}\"Shell\"${end} (UID 2000) in the list."
echo -e "  4) Turn the toggle ${green}ON${end} to grant Root access."
echo -e ""
echo -e "${yellow}==================================================${end}"
echo -e "${cyan}[*] Waiting for Root access... Please enable the toggle on your phone${end}"

while true; do
    if adb shell "su -c 'id'" 2>/dev/null | grep -q "uid=0"; then
        echo -e "\n${green}[+] Success! Root access granted for ADB Shell (UID 0)${end}"
        break
    else
        sleep 3
    fi
done

# ==============================================================================
# BULK PUSHING ALL ZIP MODULES TO THE DEVICE
# ==============================================================================
echo -e "\n${cyan}[*] Pushing all downloaded zip modules to /data/local/tmp/...${end}"

if ls "$TMP_DIR"/*.zip &>/dev/null; then
    if adb push "$TMP_DIR"/*.zip /data/local/tmp/ &>/dev/null; then
        echo -e "${green}[+] All modules successfully transferred to the phone${end}"
    else
        echo -e "${red}[-] Failed to transfer some zip files!${end}"
    fi
else
    echo -e "${red}[-] No zip modules found in $TMP_DIR to push!${end}"
    exit 1
fi

# Detect which KernelSU binary is available on the device (ksu_cli or ksud)
KSU_BINARY=$(adb shell "su -c 'which ksu_cli || which ksud'" 2>/dev/null | tr -d '\r\n')

if [[ -z "$KSU_BINARY" ]]; then
    echo -e "${red}[-] Error: Neither ksu_cli nor ksud was found on the device!${end}"
    echo -e "${red}    Please make sure KernelSU is properly integrated into your kernel${end}"
    exit 1
fi

install_module() {
    local MODULE_LABEL="$1"
    local MODULE_NAME="$2"
    adb shell "su -c '$KSU_BINARY module install /data/local/tmp/$MODULE_NAME'"

    if [[ $? -eq 0 ]]; then
        echo -e "${green}[+] $MODULE_LABEL installed successfully (Default config applied)${end}"
    else
        echo -e "${red}[-] Failed to install $MODULE_LABEL!${end}"
        exit 1
    fi
    adb shell "rm -f /data/local/tmp/$MODULE_NAME"
}

# ==============================================================================
# INSTALLING META-HYBRID_MOUNT & HANDLING AUTOMATIC TIMEOUT
# ==============================================================================
echo -e "\n${yellow}=== Installing Core Meta-Module ===${end}"
echo -e "${cyan}[*] Installing meta-hybrid_mount.zip...${end}"
echo -e "${red}    !!! IMPORTANT !!!${end}"
echo -e "${red}    The module installer might prompt for Volume Keys selection on the phone screen${end}"
echo -e "${red}    DO NOT TOUCH the phone or press any keys!${end}"
echo -e "${red}    The script will automatically use default settings after a 15-second timeout${end}"

install_module "Hybrid-Mount" "meta-hybrid_mount.zip"

# ==============================================================================
# REBOOT & INTERACTIVE WAIT FOR DEVICE TO COME ALIVE
# ==============================================================================
echo -e "\n${yellow}=== Rebooting Device to Activate Meta-Module ===${end}"
echo -e "${red}    !!! DO NOT TOUCH THE PHONE OR CLOSE THE SCRIPT !!!${end}"
echo -e "${cyan}[*] The work is still in progress. Sending reboot command...${end}"

adb reboot

echo -e "${cyan}[*] Phone is rebooting. Waiting for it to disconnect...${end}"
sleep 5

echo -e "${cyan}[*] Waiting for the phone to boot up and come back online...${end}"

adb wait-for-device

while true; do
    BOOT_COMPLETED=$(adb shell "getprop sys.boot_completed" 2>/dev/null | tr -d '\r\n')
    if [[ "$BOOT_COMPLETED" == "1" ]]; then
        echo -e "${green}[+] Device is fully booted and back in service!${end}"
        break
    else
        sleep 3
    fi
done

echo -e "${green}[+] Meta-module is active now${end}"
echo -e "${yellow}==================================================${end}"

# ==============================================================================
# INSTALLING REMAINING KERNELSU SUITE MODULES
# ==============================================================================
echo -e "\n${yellow}=== Installing Remaining KernelSU Suite Modules ===${end}"

install_module "NeoZygisk"      "NeoZygisk.zip"
install_module "Vector"         "Vector.zip"
install_module "Integrity-Box"  "Integrity-Box.zip"
install_module "TEESimulator"   "TEESimulator.zip"

# ==============================================================================
# FINAL REBOOT & COMPLETION
# ==============================================================================
echo -e "\n${cyan}==================================================${end}"
echo -e "${green}[+] All components of KernelSU Suite installed successfully!${end}"
echo -e "${yellow}[*] Rebooting the device one last time to activate everything...${end}"
echo -e "${cyan}==================================================${end}"

adb reboot

# ==============================================================================
# LOCAL CLEANUP
# ==============================================================================
if [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
fi

echo -e "\n${green}🎉 SUCCESS: Script execution finished!${end}"
echo -e "${light_grey}You can safely close this terminal now${end}"
echo -e "${light_grey}Once the phone boots up, all modules will be active${end}\n"
