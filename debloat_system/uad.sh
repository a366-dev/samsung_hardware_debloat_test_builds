#!/bin/bash
#
# This tool is designed to debloat
# the super.img according to the
# UAD.ng (it will be downloaded
# by the main script)
#

usage() {
    echo -e "\e[3;36mUsage: $0 -l <level> <path-to-super>\e[0m"
    echo -e ""
    echo -e "\e[3;36mOptions:\e[0m"
    echo -e "  \e[3;36m-l, --level      Level of removal: (R)ecommended, (A)dvanced, (E)xpert\e[0m"
    echo -e "                     \e[3;36m(Each level includes the previous ones)\e[0m"
    echo -e "  \e[3;36m-h, --help       Show this help message\e[0m"
    echo -e ""
    echo -e "\e[3;36mExample:\e[0m"
    echo -e "  \e[3;36m$0 -l A /path/to/super.img\e[0m"
    exit 1
}

if [[ $# -eq 0 ]]; then usage; fi

typeset -l CLEAN_MODE
CLEAN_MODE=''
SUPER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--level)
            CLEAN_MODE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            SUPER=$(realpath "$1")
            shift
            ;;
    esac
done

if [[ -z "$CLEAN_MODE" || -z "$SUPER" ]]; then
    echo -e "\e[1;31m[-] Error: Missing level or path.\e[0m\n"
    usage
fi

case $CLEAN_MODE in
    "r")
        JQ_FILTER='.value.removal == "Recommended"'
        ;;
    "a")
        JQ_FILTER='.value.removal == "Recommended" or .value.removal == "Advanced"'
        ;;
    "e")
        JQ_FILTER='.value.removal == "Recommended" or .value.removal == "Advanced" or .value.removal == "Expert"'
        ;;
    *)
        echo -e "\e[1;31m[-] Unknown level: $CLEAN_MODE\e[0m"
        exit 1
        ;;
esac

SCRIPT_ROOT_DIR=$(realpath $(dirname "$0"))
WHITELIST=$(grep -v -e '^#' -e '^$' "$SCRIPT_ROOT_DIR/whitelist.conf" | awk '{print $1}')

UAD_LISTS=$(cat "$SCRIPT_ROOT_DIR/UAD.ng")
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to cat UAD.ng\e[0m'
    # TODO: Verify that clean_super.sh correctly
    #           handles exit codes from local
    #           scripts
    exit 1
fi

TO_REMOVE=$(jq -r "to_entries[] | select($JQ_FILTER) | .key" <<< "$UAD_LISTS")

echo -e '\e[3;36m[+] Generating all installed packages list\e[0m'
APPS=$(find "$SUPER/product/app" -mindepth 1 -maxdepth 1 -type d)
APPS+=$'\n'$(find "$SUPER/product/priv-app" -mindepth 1 -maxdepth 1 -type d)
APPS+=$'\n'$(find "$SUPER/system/system/app" -mindepth 1 -maxdepth 1 -type d)
APPS+=$'\n'$(find "$SUPER/system/system/priv-app" -mindepth 1 -maxdepth 1 -type d)
APPS+=$'\n'$(find "$SUPER/system_ext/app" -mindepth 1 -maxdepth 1 -type d)
APPS+=$'\n'$(find "$SUPER/system_ext/priv-app" -mindepth 1 -maxdepth 1 -type d)

clean_xml_entry() {
    local XML_PATH="$1"
    local PACKAGE_NAME="$2"

    # Remove all tags containing $package_name
    sudo xmlstarlet ed -L -d "//*[@*='$PACKAGE_NAME' or @*[starts-with(., '$PACKAGE_NAME/')]]" "$XML_PATH" &> /dev/null

    # Clean up empty parent tags left after removal
    sudo xmlstarlet ed -L -d "//*[not(@*) and not(*) and not(text()[normalize-space()])]" "$XML_PATH" &> /dev/null

    local COUNT=$(sudo xmlstarlet sel -t -v "count(/*/*)" "$XML_PATH" 2> /dev/null)

    if [[ -z "$COUNT" || "$COUNT" -eq 0 ]]; then
        sudo rm "$XML_PATH"
        echo -e "           \e[1;32m[*] Removed empty XML: $XML_PATH\e[0m"
    else
        echo -e "           \e[1;33m[*] Removed tags from XML: $XML_PATH\e[0m"
    fi
}

echo -e '\e[3;36m[+] Processing apps\e[0m'

COUNT=$(( $(echo -n "$APPS" | tr -dc '\n' | wc -c) + 1))
DONE_COUNT=0
REMOVED_COUNT=0

while read -r APP; do
    [[ -z "$APP" ]] && continue
    DONE_COUNT=$(( $DONE_COUNT + 1 ))
    BASENAME=$(basename "$APP")
    PACKAGE_NAME=$(aapt dump badging "$APP/$BASENAME".apk 2> /dev/null | rg -e "package: name=\'([^\']+)\'" -or '$1')
    echo -e "   \e[3;36m[*] $PACKAGE_NAME [\e[3;31m$DONE_COUNT\e[3;36m/\e[3;31m$COUNT\e[3;36m]\e[0m"
    if [[ $'\n'"$TO_REMOVE"$'\n' = *$'\n'"$PACKAGE_NAME"$'\n'* ]]; then
        if [[ $'\n'"$WHITELIST"$'\n' != *$'\n'"$PACKAGE_NAME"$'\n'* ]]; then
            DESC=$(jq -r ".\"$PACKAGE_NAME\".description // empty" <<< "$UAD_LISTS")
            if [[ -n "$DESC" ]]; then
                echo -e '       \e[3;36m[*] Description:\e[0m'
                echo -e "\e[3;35m$DESC\e[0m" | sed 's/^/            /'
            fi
            
            echo -e "       \e[3;33m[+] Removing: $APP\e[0m"
            
            ETC_PATH="$(dirname $(dirname "$APP"))/etc"
            
            for SUB_DIR in 'sysconfig' 'permissions' 'default-permissions'; do
                FULL_PATH_TO_SUB_DIR="$ETC_PATH/$SUB_DIR"
                IFS=$'\n' read -r -d '' -a XML_FILES < <(grep -rl "\"$PACKAGE_NAME\"" "$FULL_PATH_TO_SUB_DIR" 2> /dev/null; printf '\0')

                if [[ ${#XML_FILES[@]} -eq 1 && -z "${XML_FILES[0]}" ]]; then
                    XML_FILES=()
                fi

                if [[ ${#XML_FILES[@]} -gt 0 ]]; then
                    for XML_FILE in "${XML_FILES[@]}"; do
                        clean_xml_entry "$XML_FILE" "$PACKAGE_NAME"
                    done
                else
                    echo -e "           \e[1;31m[-] No XML file found in $FULL_PATH_TO_SUB_DIR\e[0m"
                fi
            done
            sudo rm -rf $APP
            REMOVED_COUNT=$(( $REMOVED_COUNT + 1 ))
        else
            echo -e '       \e[3;32m[+] Seems like this app is whitelisted. Skipping\e[0m'
        fi
    else
        echo -e '       \e[3;32m[+] Seems like this app is not listed in the UAD-NG list. Skipping\e[0m'
    fi
done <<< "$APPS"

echo -e "\e[3;32m[+] Done! \e[1;31m$REMOVED_COUNT\e[0m\e[3;32m/\e[1;33m$DONE_COUNT\e[0m \e[3;32mremoved \e[3;36m(\e[1;35m$(( $DONE_COUNT - $REMOVED_COUNT )) \e[3;36mskipped)\e[0m"
