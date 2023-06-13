#!/usr/bin/env bash

REMOVE_DOMAINS=("${@}")
CONFIG_PATH="/opt/docker/certmanager/dnsrobocert/config.yml"

GREEN='\033[0;32m'  # Green
RED="\033[0;31m"    # Red
COLOR_OFF="\033[0m" # Text Reset

if [[ -z ${1} ]]; then
    echo -e "\n${GREEN}Run this script:\n${RED}  ${0##*/} <domain-name.com>${COLOR_OFF}\n"
    exit 1
fi

checkLock() {
    if [[ $(pgrep -fc "${0##*/}") -ne 1 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}

checkDependencies() {
    deps=(yq)
    function installed {
        cmd=$(command -v "${1}")
        [[ -n "${cmd}" ]] && [[ -f "${cmd}" ]]
        return ${?}
    }
    function die {
        echo >&2 "Fatal: ${*}"
        exit 1
    }
    for dep in "${deps[@]}"; do
        installed "${dep}" || die "Missing '${dep}'"
    done
}

remove_domain() {
    for DOMAIN in "${REMOVE_DOMAINS[@]}"; do
        echo "Remove domain: ${DOMAIN}"
        cp ${CONFIG_PATH} /tmp/
        yq -i "del(.certificates|.[]| select(.domains.[] == \"${DOMAIN}\"))" "${CONFIG_PATH}"
    done
}

main() {
    checkLock
    checkDependencies
    remove_domain
}

main
