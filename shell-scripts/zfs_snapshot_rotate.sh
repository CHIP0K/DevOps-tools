#!/usr/bin/env bash
source /etc/environment

SNAPSHOT_TIME=$(date +'%Y-%m-%d_%H-%M-%S')
ROTATE_HOURS="24"
LOGFILE=/var/log/zfs.log
ZPOOL_NAME="zp_mysql"
ZFS_DATASET="mysql/data"


checkLock() {
    if [[ $(pgrep -fc "${0##*/}") -ne 1 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}

# Function to create a snapshot with the current date and time
create_snapshot() {
    local snapshot_name="${ZPOOL_NAME}/${ZFS_DATASET}@${SNAPSHOT_TIME}"
    zfs snapshot "$snapshot_name"
    echo "${SNAPSHOT_TIME} | created zfs snapshot: $snapshot_name" >>${LOGFILE}
}

# Function to delete snapshots older than 24 hours
delete_old_snapshots() {
    local cutoff_time=$(date -d "${ROTATE_HOURS} hours ago" +"%s")
    zfs list -H -t snapshot -o name,creation -r "$ZPOOL_NAME/$ZFS_DATASET" |
    while read -r snapshot_name creation_time; do
        local snapshot_time=$(date -d "$creation_time" +'%s')
        if ((snapshot_time < cutoff_time)); then
            zfs destroy "$snapshot_name"
            echo "${SNAPSHOT_TIME} | destroyed zfs snapshot: $snapshot_name" >>${LOGFILE}
        fi
    done
}

main() {
    checkLock
    create_snapshot
    delete_old_snapshots
}

main
