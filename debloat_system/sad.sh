#!/bin/bash
#
# This tool is designed to
# download apks from
# Samsung servers
#

yellow='\033[93m'
red='\033[91m'
blue='\033[94m'
green='\033[92m'
end='\033[0m'

show_help() {
    echo "Usage: $0 -m 'device-model' -v 'sdk-version' -p 'package-name'"
    echo "  -m : Samsung model in 'SM-XXXXX' format "
    echo "  -v : Android SDK version (for example: 26, 28, 29)"
    echo "  -p : Package name (for example: com.sec.android.app.popupcalculator)"
    echo "Environment variables:"
    echo "  OUT_DIR : Custom output directory for the downloaded APK (optional, defaults to current directory)"
    echo "  OUT_NAME : Custom output name for the downloaded APK (optional, defaults to <package_name>-<vs_code>.apk)"
    exit 1
}

while getopts "m:v:p:h" opt; do
    case "$opt" in
        m) model="${OPTARG}" ;;
        v) sdk_ver="${OPTARG}" ;;
        p) package_name="${OPTARG}" ;;
        h|*) show_help ;;
    esac
done

if [[ -z "$package_name" || -z "$model" || -z "$sdk_ver" ]]; then
    show_help
    exit 1
fi

model=$(echo "$model" | tr '[:lower:]' '[:upper:]')

url="https://vas.samsungapps.com/stub/stubDownload.as?appId=$package_name&deviceId=$model"
url="$url&mcc=425&mnc=01&csc=ILO&sdkVer=$sdk_ver&pd=0&systemId=1608665720954&callerId=com.sec.android.app.samsungapps" \
url="$url&abiType=64&extuk=0191d6627f38685f"

echo -e "${blue}Requesting Samsung servers...${end}"
xml_response=$(curl -s "$url")

result_code=$(echo "$xml_response" | sed -n 's|.*<resultCode>\([^<]*\)</resultCode>.*|\1|p')
result_msg=$(echo "$xml_response" | sed -n 's|.*<resultMsg>\([^<]*\)</resultMsg>.*|\1|p')

if [[ "$result_code" != "1" || -z "$result_code" ]]; then
    if [[ -n "$result_msg" ]]; then
        echo -e "${blue}Samsung Servers: ${red}\"${result_msg}\"${end}"
    else
        echo -e "${red}No results!${end}"
    fi
    exit 1
fi

vs_code=$(echo "$xml_response" | sed -n 's|.*<versionCode>\([^<]*\)</versionCode>.*|\1|p')
vs_name=$(echo "$xml_response" | sed -n 's|.*<versionName>\([^<]*\)</versionName>.*|\1|p')
download_uri=$(echo "$xml_response" | sed -n 's|.*<downloadURI><!\[CDATA\[\([^]]*\)\]\]></downloadURI>.*|\1|p')

echo -e "${blue}\nThe available versionCode is: ${yellow}${vs_code}"
echo -e "${blue}The available versionName is: ${yellow}${vs_name}${end}\n"

echo -e "\n${blue}Download started!...${end}"
local_dir=$(realpath "${OUT_DIR:-$(pwd)}")
output_file="${local_dir}/${OUT_NAME:-${package_name}-${vs_code}.apk}"
    
curl -L -o "$output_file" "$download_uri"

echo -e "${blue}APK saved: ${yellow}${output_file}${end}"
