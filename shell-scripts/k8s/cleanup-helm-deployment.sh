#!/usr/bin/env bash

DAYS=2
K_NAMESPACE="web2app-landings-dev"

case $(uname) in
  Linux)
    PARSE_DATES=$(date -d "${DAYS} days ago" "+%Y-%m-%d")
    ;;
  Darwin)
    PARSE_DATES=$(date -v -${DAYS}d "+%Y-%m-%d")
    ;;
  *)
    echo "Unknown OS"
    exit 1
    ;;
esac

checkDependencies() {
    deps=(helm kubectl jq)
    function installed {
        cmd=$(command -v "${1}")
        [[ -n "${cmd}" ]] && [[ -f "${cmd}" ]]
        return ${?}
    }
    function die {
        echo -e "${RED}Fatal: ${*}${COLOR_OFF}" >&2
        exit 1
    }
    for dep in "${deps[@]}"; do
        installed "${dep}" || die "Missing '${dep}'"
    done
}

list_deployments() {
    helm list -n ${K_NAMESPACE} --output json |
        jq -r ".[] | select(.updated < \"${PARSE_DATES}\") | .name"
}

delete_deployments() {
    for i in $(list_deployments); do
        helm delete -n ${K_NAMESPACE} "${i}"
    done
}

main() {
    delete_deployments
}

main
