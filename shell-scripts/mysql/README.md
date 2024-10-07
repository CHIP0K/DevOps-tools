# Description about scripts

## convert-to-json.sh

The `convert-to-json.sh` script is a shell script designed to convert data from a MySQL table to JSON format. It includes functions to generate a JSON template from table columns, export the JSON data from a table, and dump all tables in a database to JSON. The script allows specifying a database, table, and a limit range for data export, and handles both single table and multiple tables conversions.

## for only script

If you have to convesion a single table: set variable DB_TABLE=tablename
If commenting DB_TABLE, this is a script to convesion all tables in the database
If you have to convesion a single table with a primary key: set variable PRIMARY_INDEX_KEY=primary_key

### Example import to elasticsearch with usage logstash

* Go to the work path and unarchive data

```shell
cd /home/user/convert
gunzip data_file.json.gz
```

* Create logstash config

```shell
cat > ./logstash.yml <<'EOF'
input {
  file {
    type => "json"
    codec => "json"
    path => "/home/user/convert/data_file.json"
    start_position => "beginning"
  }
}
filter {
  json {
    source => "message"
  }
  date {
    match => ["created_at", "yyyy-MM-dd HH:mm:ss.SSSSSS"]
    target => "@timestamp"
  }
  date {
    match => ["updated_at", "yyyy-MM-dd HH:mm:ss.SSSSSS"]
    target => "updated_at"
  }
  date {
    match => ["created_at", "yyyy-MM-dd HH:mm:ss.SSSSSS"]
    target => "created_at"
  }
  mutate {
    remove_field => ["tags", "log", "event", "host", "@version"]
  }
}
output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "file_imported_%{+YYYY_MM}"
    user => "user"
    password => "password"
  }
}
EOF
```

* And run import data from json file to elasticsearch database

```shell
rm -rf /home/user/convert/data_file/*; /usr/share/logstash/bin/logstash -f /home/user/convert/logstash.yml --path.data /home/user/convert/data_file
```
