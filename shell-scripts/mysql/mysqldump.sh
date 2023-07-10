#!/usr/bin/env bash
source /etc/environment

MYSQL_CONFIG_PATH="${1:-~/.my.cnf}"
DUMP_FORMAT="${2:-table}" # Avaliable formats "table|full|all", default table
DUMP_PATH="${3:-/opt/backups/}"

TODAY=$(date +"%F")
DUMP_HOST_IDENTITY="${HOSTNAME_}${TODAY}"
DUMP_TIME=$(date +"%F_%R")

DUMP_ROTATE_DAYS="3"
COPY_TO_S3="yes"
S3_DUMP_ROTATE_DAYS=30
S3CMD_BUCKET="db.backup/mysqldump-for-slave"

BACKUP_DATABASES="
db1
db2
"

checkLock() {
    if [[ $(pgrep -fc "${0##*/}") -ne 1 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}

checkDependencies() {
    deps=(mysql mysqldump find gzip s3cmd)
    function installed {
        cmd=$(command -v "${1}")
        [[ -n "${cmd}" ]] && [[ -f "${cmd}" ]]
        return ${?}
    }
    function die {
        echo >&2 "Fatal: ${*}"
        exit 1
    }
    for dep in "${deps[@]}"; do
        installed "${dep}" || die "Missing '${dep}'"
    done
}

dumpPrepare() {
    # Create Backup sub-directories
    MBD="${DUMP_PATH}/${DUMP_HOST_IDENTITY}/mysql"
    install -d "${MBD}"
    find "${DUMP_PATH}" -type f -mtime +"${DUMP_ROTATE_DAYS}" -delete # Remove old files
}

createDumpTable() {
    echo -e "Create a mysql dump tables"
    for db in $BACKUP_DATABASES; do
        DB_PATH="${MBD}/${db}.table.${DUMP_TIME}"
        install -d "${DB_PATH}"
        for dump_table in $(mysql --defaults-file="${MYSQL_CONFIG_PATH}" -Bse "show tables from \`${db}\`"); do
            FILE_TABLE_DATA="${DB_PATH}/${dump_table}.sql"
            FILE_TABLE_SCHEMA="${DB_PATH}/${dump_table}-schema.sql"
            mysqldump --no-tablespaces \
                --set-gtid-purged=OFF \
                --no-data \
                --single-transaction \
                "${db}" "${dump_table}" | gzip -9 >"${FILE_TABLE_SCHEMA}.gz"
            mysqldump --no-tablespaces \
                --set-gtid-purged=OFF \
                --single-transaction \
                "${db}" "${dump_table}" | gzip -9 >"${FILE_TABLE_DATA}.gz"
        done
    done
}

createDumpFull() {
    echo -e "Create a mysql dump full"
    for db in $BACKUP_DATABASES; do
        DB_PATH="${MBD}/${db}.full.${DUMP_TIME}"
        install -d "${DB_PATH}"
        mysqldump --single-transaction \
            --quick --add-drop-database \
            --add-drop-table --triggers \
            --routines \
            --events \
            --source-data \
            --no-tablespaces \
            --databases "${db}" | gzip >"${DB_PATH}"/"${db}".sql.gz
    done
}

createDump() {
    case $DUMP_FORMAT in
    table)
        createDumpTable
        ;;
    full)
        createDumpFull
        ;;
    all)
        createDumpTable
        createDumpFull
        ;;
    *)
        echo "Avaliable formats: \"table|full|all\", default: table"
        ;;
    esac
}

s3RotateDumps() {
    OLDER_THOSE_DAYS=$(date --date "${S3_DUMP_ROTATE_DAYS} days ago" +%s)
    for db_dump in ${BACKUP_DATABASES}; do
        s3cmd ls s3://"${S3CMD_BUCKET}"/"${db_dump}"."${DUMP_FORMAT}" | awk '{print $2}'
    done |
        while read -r line; do
            CREATED_DAY=$(echo -e "${line}" | awk -F. 'END {print $(NF)}' | tr '/_' ' ')
            CREATED_DAY_TIMESTAMP=$(date -d "${CREATED_DAY}" +%s)
            if [[ ${CREATED_DAY_TIMESTAMP} -lt ${OLDER_THOSE_DAYS} ]]; then
                echo -e "delete: ${line}"
                s3cmd del --recursive "${line}"
            fi
        done
}

pushDumpS3CMD() {
    COPY_DUMPS=$(find "${MBD}" -type d -name *"${DUMP_TIME}" -exec basename \{} \;)
    for DUMP_NAME in $COPY_DUMPS; do
        s3cmd sync "${MBD}"/"${DUMP_NAME}"/* s3://"${S3CMD_BUCKET}"/"${DUMP_NAME}"/ &>/dev/null
    done
}

main() {
    checkDependencies &&
        checkLock &&
        dumpPrepare &&
        createDump
    if [[ ${COPY_TO_S3} == "true" ]] || [[ ${COPY_TO_S3} == "yes" ]]; then
        pushDumpS3CMD &&
            s3RotateDumps
    fi
}

main
