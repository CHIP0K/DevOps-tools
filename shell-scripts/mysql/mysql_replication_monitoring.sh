#!/usr/bin/env bash
source /etc/environment

# Variables
TELEGRAM_API_KEY=""
TELEGRAM_CHAT_ID=""

# Functions
checkLock() {
    if [[ $(pgrep -fc "${0##*/}") -gt 2 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}
TelegramNotify() {
    read -r TEXT
    if [[ "${TEXT:-0}" != "0" ]]; then
        curl -s --max-time 10 "https://api.telegram.org/bot${TELEGRAM_API_KEY}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}&disable_web_page_preview=1&text=$TEXT"
    fi
}
selectReplicationChannels() {
    mysql -Bse \
        "SELECT
            CHANNEL_NAME
        FROM
            performance_schema.replication_connection_status;" |
    tr '\n' ' '
}
getChannelStatus() {
    mysql -Bsre \
        "SELECT
            CHANNEL_NAME,SERVICE_STATE,LAST_ERROR_MESSAGE,LAST_ERROR_NUMBER
        FROM
            performance_schema.replication_connection_status
        WHERE
            CHANNEL_NAME = \"${REP_CHANNEL}\"\G;" |
        grep -v '\*' | tr -d ' '
    echo
}
checkKeys() {
    case $KEY in
    CHANNEL_NAME)
        CHANNEL=$VALUE
        ;;
    LAST_ERROR_MESSAGE)
        ERROR_MESSAGE=${VALUE:-0}
        ;;
    SERVICE_STATE)
        if [[ $VALUE != ON ]]; then
            echo -e "HOSTNAME=${HOSTNAME}, CHANNEL=${CHANNEL}, ${KEY}=${VALUE}%0A"
        fi
        ;;
    LAST_ERROR_NUMBER)
        if [[ $VALUE -ne 0 ]]; then
            echo -e "HOSTNAME=${HOSTNAME}, CHANNEL=${CHANNEL}, ${KEY}=${VALUE}, ERROR_MESSAGE=${ERROR_MESSAGE}%0A"
        fi
        ;;
    esac
}
channelStatus() {
    REP_CHANNELS=$(selectReplicationChannels)
    for REP_CHANNEL in ${REP_CHANNELS}; do
        for STATE in $(getChannelStatus); do
            KEY=$(echo "${STATE}" | awk -F':' '{print $1}')
            VALUE=$(echo "${STATE}" | awk -F':' '{print $2}')
            checkKeys
        done
    done
}

# Main block
main() {
    checkLock
    STATUS=$(channelStatus)
    echo ${STATUS} | TelegramNotify
}

main
