#!/usr/bin/env bash

GREEN='\033[0;32m'  # Green
YELLOW="\033[0;33m" # Yellow
RED="\033[0;31m"    # Red
COLOR_OFF="\033[0m" # Text Reset

help() {
    echo -e "${GREEN}git config --global core.hooksPath ${YELLOW}${0##*/}${COLOR_OFF}"
}

check() {
    # Run gitleaks with parameters
    gitleaks detect --report-format json --redact -v --log-opts "HEAD~1..HEAD"

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