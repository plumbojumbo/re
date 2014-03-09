#!/bin/bash

# undress.sh - Pants down.
# David Goldwich
# 2013-11-03

while getopts ':v' OPT; do
    if [ "${OPT}" = "v" ]; then
        VERBOSE=1;
    fi
    shift
done

FILE_ARG="$1"

if [ -z "${FILE_ARG}" ] || [ ! -r "${FILE_ARG}" ]; then
    printf "Usage: $0 [-v] file\n"
    exit 1
fi

FILE_NAME=$(basename "${FILE_ARG}")
FOLDER=$(dirname "${FILE_ARG}")
FILE_PATH=$(cd "${FOLDER}"; pwd)/${FILE_NAME}

RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

FAIL=0

log_start() {
    printf "  ‣ $1"
}

log_success() {
    [ -n "${VERBOSE}" ] && printf "\r "
    printf " ${GREEN}✓${RESET}\n"
}

log_fail() {
    [ -n "${VERBOSE}" ] && printf "\r "
    printf " ${RED}✘${RESET}\n"
}

run() {
    [ -n "${VERBOSE}" ] && log_start "$1"
    eval "$2 2> /dev/null" && {
        if [ -n "${VERBOSE}" ]; then
            log_success
        fi
    } || {
        [ -n "${VERBOSE}" ] && log_fail
        FAIL=1
    }
}

if [ -n "${VERBOSE}" ]; then
    printf "File: ${FILE_PATH}\n"
fi

ARCHS=($(lipo -info "${FILE_PATH}" 2> /dev/null | sed -E 's/^.+: //'))

for ARCH in ${ARCHS[@]}; do
    FAIL=0
    ARCH_BASE="${FILE_NAME}/${ARCH}"
    printf "Undressing ${ARCH_BASE}"
    [ -n "${VERBOSE}" ] && printf "\n"
    mkdir -p "${ARCH_BASE}"

    run "headers" "otool -afh -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/mach_o_headers.txt\""
    run "load commands" "otool -l -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/load_commands.txt\""
    run "symbols" "nm -ap -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/symbols.txt\""
    run "shared libs" "otool -L -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/shared_libs.txt\""
    run "__TEXT w/ otool" "otool -tV -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/text.txt\""
    run "__TEXT w/ otx" "otx -b -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/text_otx.txt\""
    run "class-dump" "class-dump -aAH --arch \"${ARCH}\" -o \"${ARCH_BASE}/Headers/\" \"${FILE_PATH}\""
    run "strings" "strings -ao -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/strings.txt\""
    run "__DATA" "otool -dV -arch \"${ARCH}\" \"${FILE_PATH}\" > \"${ARCH_BASE}/data.txt\""

    if [ -z "${VERBOSE}" ]; then
        if [ ${FAIL} -eq 1 ]; then
            log_fail
        else
            log_success
        fi
    fi
done

printf "${#ARCHS[@]} architecture(s) undressed.\n"

exit ${FAIL}
