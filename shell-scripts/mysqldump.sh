#!/usr/bin/env bash
source /etc/environment
MYSQL_CONFIG_PATH="${1:-~/.my.cnf}"

DUMP_FORMAT="${2:-table}" # Avaliable formats "table|full|all", default table
DUMP_PATH="${3:-/opt/backups/}"
DUMP_ROTATE_DAYS="3"
DUMP_HOST_IDENTITY="$(hostname)_$(date +"%d-%m-%Y")" # Get date in dd-mm-yyyy_s format
DUMP_TIMESTAMP="$(date +"%d-%m-%Y_%s")"
S3CMD_BUCKET="db.backup/mysqldump-for-slave"

BACKUP_DATABASES="
db1
db2
"

dumpPrepare() {
    # Create Backup sub-directories
    MBD="${DUMP_PATH}/${DUMP_HOST_IDENTITY}/mysql"
    install -d "${MBD}"

    find "${DUMP_PATH}" -type f -mtime +"${DUMP_ROTATE_DAYS}" -delete # Remove old files
}

createDumpTable() {
    echo -e "Create a mysql dump tables"
    for db in $BACKUP_DATABASES; do
        DB_PATH="${MBD}/${db}-table-${DUMP_TIMESTAMP}"
        install -d "${DB_PATH}"
        for dump_table in $(mysql --defaults-file="${MYSQL_CONFIG_PATH}" -Bse "show tables from \`${db}\`"); do
            FILE_TABLE_DATA="${DB_PATH}/${dump_table}.sql"
            FILE_TABLE_SCHEMA="${DB_PATH}/${dump_table}-schema.sql"
            mysqldump --no-tablespaces --set-gtid-purged=OFF --no-data --single-transaction "${db}" "${dump_table}" | gzip -9 >"${FILE_TABLE_SCHEMA}.gz"
            mysqldump --no-tablespaces --set-gtid-purged=OFF --single-transaction "${db}" "${dump_table}" | gzip -9 >"${FILE_TABLE_DATA}.gz"
        done
    done
}

createDumpFull() {
    echo -e "Create a mysql dump full"
    for db in $BACKUP_DATABASES; do
        DB_PATH="${MBD}/${db}-full-${DUMP_TIMESTAMP}"
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

pushDumpS3CMD() {
    COPY_DUMPS=$(find "${MBD}" -type d -name *"${DUMP_TIMESTAMP}" -exec basename \{} \;)
    for DUMP_NAME in $COPY_DUMPS; do
        s3cmd sync "${MBD}"/"${DUMP_NAME}"/* s3://"${S3CMD_BUCKET}"/"${DUMP_NAME}"/ &>/dev/null
    done
}

main() {
    dumpPrepare &&
        createDump &&
        pushDumpS3CMD
}

main
