#!/usr/bin/env bash
set -ueo pipefail
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
        echo -e "${RED}Fatal: ${*}${COLOR_OFF}" >&2
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
            checkDependencies
            echo -e "Installing from GitHUB"
            install_from_git
            export PS1="${PS1:-}"
            case $SHELL in
            /bin/zsh)
                echo "export PATH=${INSTALL_APP_PATH}:\$PATH" >>~/.zshrc
                . ~/.zshrc
                ;;
            /bin/bash)
                echo "export PATH=${INSTALL_APP_PATH}:\$PATH" >>~/.bashrc
                . ~/.bashrc
                ;;
            *)
                echo -e "${GREEN}If you want to use gitleaks in shell,
please modify the profile ${RED}~/.bashrc ${GREEN}or ${RED}~/.zshrc${GREEN} or other RC profile: ${YELLOW}export PATH=${INSTALL_APP_PATH}:\$PATH${COLOR_OFF}"
                ;;
            esac
        fi
    else
        echo -e "${GREEN}gitleaks is installed${COLOR_OFF}"
    fi
}

installPreCommitHOOK() {
    [[ -d "${INSTALL_APP_PATH}"/git-hook ]] || mkdir -p "${INSTALL_APP_PATH}"/git-hook
    [[ -x "${INSTALL_APP_PATH}"/git-hook/pre-commit ]] || cat >"${INSTALL_APP_PATH}"/git-hook/pre-commit <<'EOF'
#!/usr/bin/env bash

GREEN='\033[0;32m'  # Green
YELLOW="\033[0;33m" # Yellow
RED="\033[0;31m"    # Red
COLOR_OFF="\033[0m" # Text Reset

help() {
    echo -e "Enable security check for ${0##*/}:\n
    1) Copy this script to you git-hook path
    2) Rename sctipt ${0##*/} as pre-commit
    3) Run this command
        ${GREEN}git config --global core.hooksPath ${YELLOW}/path/to/this/script/${COLOR_OFF}
    "
}

check() {
    # Run gitleaks with parameters
    gitleaks detect --report-format json -v --log-opts "HEAD" --no-git

    # Return code
    if [[ $? -ne 0 ]]; then
        if [[ "$LANG" = "uk_UA.UTF-8" ]]; then
          echo -e "${RED}Помилка: Знайдені проблеми з безпекою в коді.${COLOR_OFF}"
          exit 1
        else
          echo -e "${RED}Error: Security issues have been found in the code.${COLOR_OFF}"
          exit 1
        fi
    else
        # Success check
        exit 0
    fi
}

case $1 in
    help)
    help
    ;;
    *)
    check
    ;;
esac

EOF

    chmod +x "${INSTALL_APP_PATH}"/git-hook/pre-commit
    git config --global core.hooksPath "${INSTALL_APP_PATH}"/git-hook/
    echo -e "${YELLOW}pre-commit${GREEN} hook installed to path: ${YELLOW}${INSTALL_APP_PATH}/git-hook${COLOR_OFF}\n"

}

main() {
    check_arch
    check_os
    install_on_unix
    installPreCommitHOOK
}

main
