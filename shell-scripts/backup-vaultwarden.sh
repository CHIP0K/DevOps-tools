#!/usr/bin/env bash

BACKUP_PATH="/backups"
VW_DATA_DIR="/var/lib/docker/volumes/vaultwarden-data"
DUMP_TIME=$(date +"%F_%H%M")
TODAY=$(date +"%F")
TODAY_BACKUP_PATH="${BACKUP_PATH}/${TODAY}"
NOW_TODAY_BACKUP_PATH="${TODAY_BACKUP_PATH}/vw-${DUMP_TIME}"

createBackupPathToday() {
    test -d "${TODAY_BACKUP_PATH}" || mkdir -p "${TODAY_BACKUP_PATH}"
    test -d "${NOW_TODAY_BACKUP_PATH}" || mkdir -p "${NOW_TODAY_BACKUP_PATH}"
}

dbDump() {
    # Create a backup of your database
    sqlite3 ${VW_DATA_DIR}/_data/db.sqlite3 ".backup \"${NOW_TODAY_BACKUP_PATH}/db.sqlite3\""
}

filesDump() {
    # Create an archive of the Vaultwarden docker volume.
    tar -czf "${NOW_TODAY_BACKUP_PATH}/Vaultwarden_data.tar.gz" ${VW_DATA_DIR}/_data/
}

main() {
    createBackupPathToday
    dbDump
    filesDump
}

main
