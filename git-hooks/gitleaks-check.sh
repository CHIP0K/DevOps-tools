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

checkGitleaks() {
    # Run gitleaks with parameters
    # gitleaks detect -v --log-opts "HEAD~1..HEAD"
    gitleaks protect -v

    # Return code
    if [[ $? -ne 0 ]]; then
        if [[ "$LANG" = "uk_UA.UTF-8" ]]; then
          echo -e "\n${RED}Помилка: Знайдені проблеми з безпекою в коді.${COLOR_OFF}\n"
          exit 1
        else
          echo -e "\n${RED}Error: Security issues have been found in the code.${COLOR_OFF}\n"
          exit 1
        fi
    else
        # Success check
        exit 0
    fi
}

main() {
    checkGitleaks
}

case $1 in
    help)
    help
    ;;
    gitleaks)
    checkGitleaks
    ;;
    *)
    main
    ;;
esac
