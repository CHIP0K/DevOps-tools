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

clear_old_rules() {
  for drop_rule in $(iptables -L INPUT --line-numbers | grep rate_limit | cut -d ' ' -f1 | sort -r); do
    iptables -D INPUT "${drop_rule}"
  done
}

limit_func() {
    iptables -A INPUT -p tcp --dport "${1}" -i eth0 -m state --state NEW -m comment --comment "rate_limit" -m recent --set
    iptables -A INPUT -p tcp --dport "${1}" -i eth0 -m state --state NEW -m comment --comment "rate_limit" -m recent --update --seconds $TIME_PERIOD --hitcount $BLOCKCOUNT -j $DACTION
}

main() {
  clear_old_rules
  for RL in ${LIMIT_PORTS}; do
    limit_func "${RL}"
  done
}

main
