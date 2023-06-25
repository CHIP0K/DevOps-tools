#!/usr/bin/env bash
source /etc/environment

INSTALL_APP_PATH="${HOME}/.local/bin"
GITHUB_REPO="gitleaks/gitleaks"

GREEN='\033[0;32m'  # Green
RED="\033[0;31m"    # Red
YELLOW="\033[0;33m" # Yellow
COLOR_OFF="\033[0m" # Text Reset

checkDependencies() {
  deps=(grep curl jq git)
  function installed {
    cmd=$(command -v "${1}")
    [[ -n "${cmd}" ]] && [[ -f "${cmd}" ]]
    return ${?}
  }
  function die {
    echo -e >&2 "${RED}Fatal: ${*}${COLOR_OFF}"
    exit 1
  }
  for dep in "${deps[@]}"; do
    installed "${dep}" || die "Missing '${dep}'"
  done
}

check_arch() {
    echo -e "Checking architecture support..."
    case $(uname -m) in
    i386 | i686)
        architecture="x32"
        ;;
    x86_64)
        architecture="x64"
        ;;
    arm64 | aarch64)
        architecture="arm64"
        ;;
    *)
        echo -e "\n${RED}Architecture not supported${COLOR_OFF}"
        exit 1
        ;;
    esac
    echo -e "${GREEN}Checking architecture: OK ${YELLOW}${architecture}${COLOR_OFF}"
}

check_os() {
    echo -e "Checking operating system support..."
    case $(uname -s) in
    Linux)
        operating_system="linux"
        ;;
    Darwin)
        operating_system="darwin"
        ;;
    *)
        echo -e "\n${RED}Operating system not supported${COLOR_OFF}"
        exit 1
        ;;
    esac
    echo -e "${GREEN}Checking operating system: OK ${YELLOW}${operating_system}${COLOR_OFF}"
}

check_app_release() {
    curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest |
        jq --raw-output --sort-keys \
            ".assets[]|select(.name | match(\"${operating_system}\"))|select(.name | match(\"${architecture}\")).browser_download_url"
}

install_from_git() {
    APP_FULL_URL="$(check_app_release)"
    curl -sL "${APP_FULL_URL}" | tar -xvz -C "${INSTALL_APP_PATH}"
}

install_on_unix() {
    [[ -d ${INSTALL_APP_PATH} ]] || mkdir -p "${INSTALL_APP_PATH}"
    if [[ ! -x $(which gitleaks) ]] && [[ ! -x ${INSTALL_APP_PATH}/gitleaks ]]; then
        if [[ -x $(which brew) ]]; then
            echo -e "Installing gitleaks with brew"
            brew install gitleaks
        else
            echo -e "Installing from GitHUB"
            install_from_git
            echo -e "${GREEN}If you want to use gitleaks in shell,
            please modify the profile ~/.bashrc or ~/.zshrc: ${YELLOW}export PATH=${INSTALL_APP_PATH}:\$PATH
            ${COLOR_OFF}
            "
        fi
    else
        echo -e "${GREEN}gitleaks is installed${COLOR_OFF}"
    fi
}



main() {
    checkDependencies
    check_arch && check_os
    install_on_unix
}

main
