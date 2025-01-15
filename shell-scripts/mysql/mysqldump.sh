#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# DESCRIPTION:
#   This script generates MySQL database backups using mysqldump. It is designed
#   to run in a controlled environment where the SHELL is set to /bin/bash,
#   especially when used in a crontab entry.
#
# USAGE:
#   ./mysqldump.sh /path/to/.my.cnf table /path/to/backups
#   - /path/to/.my.cnf  : Path to MySQL credentials file (contains user & password).
#   - table             : Name of the table to dump (optional if dumping all).
#   - /path/to/backups  : Directory to store backups.
#
# ENVIRONMENT:
#   - SHELL=/bin/bash: Ensures that environment variables and shell behavior
#     match interactive Bash usage.
#   - CRON: When running from crontab, the environment may differ from an
#     interactive session, so explicitly setting SHELL to /bin/bash is recommended.
#
# CRON EXAMPLE:
#   SHELL=/bin/bash
#   0 8 * * * /path/to/mysqldump.sh /path/to/.my.cnf table /path/to/backups
#-------------------------------------------------------------------------------

source /etc/environment

MYSQL_CONFIG_PATH="${1:-~/.my.cnf}"
DUMP_FORMAT="${2:-table}" # Avaliable formats "table|full|all", default table
DUMP_PATH="${3:-/opt/backups}"

TODAY=$(date +"%F")
DUMP_HOST_IDENTITY="${HOSTNAME}-${TODAY}"
DUMP_TIME=$(date +"%F_%R")

DUMP_ROTATE_DAYS="0"
COPY_TO_S3="yes"
S3_DUMP_ROTATE_DAYS=30
S3CMD_BUCKET="db.backup/expertchat-db-cluster-nyc1"
GZIP_COMPRESSION_LEVEL=9

BACKUP_DATABASES="
expertchat
"
IGNORE_TABLES_DATA="math_solvers"

readonly \
    MYSQL_CONFIG_PATH \
    DUMP_FORMAT \
    DUMP_PATH \
    TODAY \
    DUMP_HOST_IDENTITY \
    DUMP_TIME \
    DUMP_ROTATE_DAYS \
    COPY_TO_S3 \
    S3_DUMP_ROTATE_DAYS \
    S3CMD_BUCKET \
    BACKUP_DATABASES \
    IGNORE_TABLES_DATA \
    GZIP_COMPRESSION_LEVEL

check_lock_running_script() {
    if [[ $(pgrep -fc "${0##*/}") -gt 1 ]]; then
        echo "Script ${0##*/} is running"
        exit 1
    fi
}

check_dependencies() {
    deps=(mysqldump find gzip s3cmd)
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

dump_prepare() {
    # Create Backup sub-directories
    MBD="${DUMP_PATH}/${DUMP_HOST_IDENTITY}/mysql"
    install -d "${MBD}"
}

create_dump_table() {
    echo -e "Create a mysql dump tables"
    for db in $BACKUP_DATABASES; do
        DB_PATH="${MBD}/${db}.table.${DUMP_TIME}"
        install -d "${DB_PATH}"
        for dump_table in $(mysql --defaults-file="${MYSQL_CONFIG_PATH}" -Bse "show tables from \`${db}\`"); do
            FILE_TABLE_DATA="${DB_PATH}/${dump_table}.sql"
            FILE_TABLE_SCHEMA="${DB_PATH}/${dump_table}-schema.sql"
            mysqldump  --defaults-file="${MYSQL_CONFIG_PATH}" \
                 --no-tablespaces \
                --set-gtid-purged=OFF \
                --no-data \
                --single-transaction \
                "${db}" "${dump_table}" | gzip -${GZIP_COMPRESSION_LEVEL} >"${FILE_TABLE_SCHEMA}.gz"
            if [[ -z ${IGNORE_TABLES_DATA} ]] || [[ ${IGNORE_TABLES_DATA} != *"${dump_table}"* ]]; then
                mysqldump  --defaults-file="${MYSQL_CONFIG_PATH}" \
                    --no-tablespaces \
                    --set-gtid-purged=OFF \
                    --single-transaction \
                    "${db}" "${dump_table}" | gzip -${GZIP_COMPRESSION_LEVEL} >"${FILE_TABLE_DATA}.gz"
            fi
        done
    done
}

create_full_dump() {
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
            --databases "${db}" | gzip -${GZIP_COMPRESSION_LEVEL} >"${DB_PATH}"/"${db}".sql.gz
    done
}

create_dump() {
    case $DUMP_FORMAT in
    table)
        create_dump_table
        ;;
    full)
        create_full_dump
        ;;
    all)
        create_dump_table
        create_full_dump
        ;;
    *)
        echo "Avaliable formats: \"table|full|all\", default: table"
        ;;
    esac
}

rotate_local_dumps() {
    for database in ${BACKUP_DATABASES}; do
        local older_those_days=$(date --date "${DUMP_ROTATE_DAYS} days ago" +%s)
        find "${DUMP_PATH:-/opt/backups}" -type d -name *${database}* |
            while read -r line; do
                local created_day=$(echo -e "${line}" | awk -F. 'END {print $(NF)}' | tr '/_' ' ')
                local created_day_timestamp=$(date -d "${created_day}" +%s)
                if [[ ${created_day_timestamp} -lt ${older_those_days} ]]; then
                    rm -rf "${line:-/opt/backups}"
                fi
            done
    done
}

s3RotateDumps() {
    local older_those_days=$(date --date "${S3_DUMP_ROTATE_DAYS} days ago" +%s)
    for db_dump in ${BACKUP_DATABASES}; do
        s3cmd ls s3://"${S3CMD_BUCKET}"/"${db_dump}". | awk '{print $2}'
    done |
        while read -r line; do
            local created_day=$(echo -e "${line}" | awk -F. 'END {print $(NF)}' | tr '/_' ' ')
            local created_day_timestamp=$(date -d "${created_day}" +%s)
            if [[ ${created_day_timestamp} -lt ${older_those_days} ]]; then
                s3cmd del --recursive "${line}"
            fi
        done
}

pushDumpS3CMD() {
    local copy_dumps
    copy_dumps=$(find "${MBD}" -type d -name *"${DUMP_TIME}" -exec basename \{} \;)
    for DUMP_NAME in $copy_dumps; do
        s3cmd sync "${MBD}"/"${DUMP_NAME}"/* s3://"${S3CMD_BUCKET}"/"${DUMP_NAME}"/ &>/dev/null
    done
}

main() {
    check_dependencies &&
        check_lock_running_script &&
        dump_prepare &&
        create_dump
    if [[ ${COPY_TO_S3} == "true" ]] || [[ ${COPY_TO_S3} == "yes" ]]; then
        pushDumpS3CMD &&
            s3RotateDumps
    fi
    rotate_local_dumps
}

main
