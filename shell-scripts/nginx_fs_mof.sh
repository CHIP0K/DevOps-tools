#!/usr/bin/env bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Recommends
totalMem=$(echo -E "$(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 1024" | bc)
r_fsFileMax=$(echo -E "(${totalMem}/4)*256" | bc)
r_worker_rlimit_nofile=$(echo -E "$r_fsFileMax / $(grep 'cpu cores' /proc/cpuinfo | awk '{print $4}' | uniq)" | bc)

# Your values
y_fsFileMax=$(sysctl -n fs.file-max)
y_worker_rlimit_nofile=$(nginx -T |& grep worker_rlimit_nofile | awk '{print $2}' | grep -o '[0-9]\+')

if [[ "${y_fsFileMax}" = "${r_fsFileMax}" ]]; then
    echo -e "Your fs.file-max value is correct: ${GREEN}${y_fsFileMax} ${NC}"
else
    echo -e "Your fs.file-max value: ${RED}${y_fsFileMax} ${NC}| Recommending: ${GREEN}${r_fsFileMax}${NC}"
fi

if [[ "${y_worker_rlimit_nofile}" = "${r_worker_rlimit_nofile}" ]]; then
    echo -e "Your worker_rlimit_nofile is correct: ${GREEN}${y_worker_rlimit_nofile} ${NC}"
else
    echo -e "Your worker_rlimit_nofile value: ${RED}${y_worker_rlimit_nofile} ${NC}| Recommending: ${GREEN}${r_worker_rlimit_nofile}${NC}"
fi
