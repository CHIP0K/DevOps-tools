#!/usr/bin/env bash
source /etc/environment

SNAPSHOT_TIME=$(date +'%Y-%m-%d_%H-%M-%S')
ROTATE_HOURS="24"
LOGFILE=/var/log/zfs.log
ZPOOL_NAME="zp_mysql"
ZFS_DATASET="mysql/data"
MYSQL_CONFIG_PATH="${1:-~/.my.cnf}"


checkLock() {
    if [[ $(pgrep -fc "${0##*/}") -gt 2 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}

mysql_prepare() {
    case $1 in
    lock)
        mysql --defaults-file="${MYSQL_CONFIG_PATH}" -Bse "
        SET autocommit=OFF;
        FLUSH LOGS;
        FLUSH TABLES WITH READ LOCK;
        "
        ;;
    unlock)
        mysql --defaults-file="${MYSQL_CONFIG_PATH}" -Bse "
        SET autocommit=ON;
        UNLOCK TABLES;
        "
        ;;
    esac
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
    mysql_prepare lock
    create_snapshot
    mysql_prepare unlock
    delete_old_snapshots
}

main
