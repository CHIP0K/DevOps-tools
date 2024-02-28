#!/usr/bin/env bash

##########
#
#  If you have to conversion a single table: set variable DB_TABLE=tablename
#  If commenting DB_TABLE, this is a script to conversion all tables in the database
#  If you have to conversion a single table with a primary key: set variable PRIMARY_INDEX_KEY=primary_key
#
##########

# DB_DATABASE=database_name
# DB_TABLE=table_name
LIMIT_RANGE=10000
# PRIMARY_INDEX_KEY=id

function_generete_json_body() {
  COLUMNS_IN_TABLE=$(
    mysql -B --raw --silent ${DB_DATABASE} -e \
      "show columns from ${DB_TABLE};" |
      awk '{ print $1 }'
  )
  tmp_json_template=$(
    for i in ${COLUMNS_IN_TABLE}; do
      echo "\"${i}\", \`${i}\`, " | tr -d '\n'
    done
  )
  json_template=${tmp_json_template::-2}
}

function_export_json() {
  ROWS_IN_TABLE=$(mysql -B --raw --silent ${DB_DATABASE} -e "SELECT count(*) FROM ${DB_TABLE}")
  echo "ROWS_IN_TABLE ${DB_TABLE}: ${ROWS_IN_TABLE}"
  SKIP_LIMIT=0
  while [[ $SKIP_LIMIT -lt "${ROWS_IN_TABLE}" ]]; do
    if [[ $PRIMARY_INDEX_KEY ]] && [[ $DB_TABLE ]]; then
      echo "SELECT JSON_OBJECT(${json_template}) FROM ${DB_TABLE} WHERE ${PRIMARY_INDEX_KEY} > ${SKIP_LIMIT} AND ${PRIMARY_INDEX_KEY} < (${SKIP_LIMIT} + ${LIMIT_RANGE});"
      mysql --raw --silent "${DB_DATABASE}" -e \
          "SELECT JSON_OBJECT(${json_template}) FROM ${DB_TABLE} WHERE ${PRIMARY_INDEX_KEY} > ${SKIP_LIMIT} AND ${PRIMARY_INDEX_KEY} < (${SKIP_LIMIT} + ${LIMIT_RANGE});" | gzip -c -9 >>"${DB_DATABASE}.${DB_TABLE}_where.json.gz"
    else
      echo "SELECT JSON_OBJECT(${json_template}) FROM ${DB_TABLE} LIMIT ${SKIP_LIMIT}, ${LIMIT_RANGE};"
      mysql --raw --silent "${DB_DATABASE}" -e \
          "SELECT JSON_OBJECT(${json_template}) FROM ${DB_TABLE} LIMIT ${SKIP_LIMIT}, ${LIMIT_RANGE};" | gzip -c -9 >>"${DB_DATABASE}.${DB_TABLE}.json.gz"
    fi
    SKIP_LIMIT=$((SKIP_LIMIT + LIMIT_RANGE))
  done
  echo "done for table:  ${DB_TABLE}"
  echo
}

function_dump_all_tables() {
  DB_TABLES=$(mysql -B --raw --silent ${DB_DATABASE} -e "show tables")
  for DUMP_TABLE in ${DB_TABLES}; do
    DB_TABLE="${DUMP_TABLE}"
    function_generete_json_body
    function_export_json
  done
}

main() {
  if [[ $DB_TABLE ]]; then
    function_generete_json_body
    function_export_json
  else
    function_dump_all_tables
  fi
}

main
