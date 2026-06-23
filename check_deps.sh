#!/bin/env bash

REQUIRED_COMMANDS=('rg' 'java' 'tar' 'lz4' 'simg2img' 'img2simg' 'lpunpack' 'fsck.erofs' 'xmlstarlet' 'aapt' 'aapt2' 'find' 'jq')

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        echo -e "\e[1;31mError: command '$cmd' not found\e[0m"
        exit 1
    fi
done

echo "Passed"
