#!/usr/bin/env bash
source /etc/environment
# Max connection in seconds
TIME_PERIOD=60
# Max connections per IP
BLOCKCOUNT=100
# default action can be DROP or REJECT
DACTION="REJECT"
# List limitation ports
LIMIT_PORTS="80 443"
# List excluded ips
EXCLUDE_IPS='10.0.0.1 10.0.0.2'

IPT="iptables"
# IPT="echo" # for debug uncoment

clear_old_rules() {
    for drop_rule in $(iptables -L INPUT --line-numbers | grep rate_limit | cut -d ' ' -f1 | sort -gr); do
        ${IPT} -D INPUT "${drop_rule}"
    done
}

exclude_ips() {
    if [[ -n ${2} ]]; then
        ${IPT} -A INPUT -p tcp --dport "${1}" -i eth0 -s "${2}"/32 -m comment --comment "rate_limit" -j ACCEPT
    fi
}

port_limit() {
    ${IPT} -A INPUT -p tcp --dport "${1}" -i eth0 -m state --state NEW \
    -m comment --comment "rate_limit" -m recent --set
    ${IPT} -A INPUT -p tcp --dport "${1}" -i eth0 -m state --state NEW \
    -m comment --comment "rate_limit" -m recent --update --seconds $TIME_PERIOD \
    --hitcount $BLOCKCOUNT -j $DACTION
}

main() {
    clear_old_rules
    for EXCL in ${EXCLUDE_IPS}; do
        for RL1 in ${LIMIT_PORTS}; do
            exclude_ips "${RL1}" "${EXCL}"
        done
    done
    for RL in ${LIMIT_PORTS}; do
        port_limit "${RL}"
    done
}

main
