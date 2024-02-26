# DevOps-tools

![DevOps tools workflow status](https://github.com/CHIP0K/DevOps-tools/actions/workflows/main.yml/badge.svg?branch=main&event=push)

## Scripts

| Name | Description |
|------|-------------|
| [iptables_rate_limit.sh](shell-scripts/iptables_rate_limit.sh) | Rate limit requests with iptables |
| [sentry-backup.sh](shell-scripts/sentry-backup.sh) | Backup and upload sentry dump to nexus storage |
| [mysqldump.sh](shell-scripts/mysql/mysqldump.sh) | Backup and upload Mysql databases to S3 storage |
| [zfs_snapshot_rotate.sh](shell-scripts/zfs_snapshot_rotate.sh) | Create zfs snapshots and remove all snapshots that are older than 24 hours |
| [mysql_replication_monitoring.sh](shell-scripts/mysql/mysql_replication_monitoring.sh) | Base monitoring tool for MySQL multisource replication, with notify to telegram |
| [backup-vaultwarden.sh](shell-scripts/backup-vaultwarden.sh) | Create VaultVarden dump |
| [convert-to-json.sh](shell-scripts/mysql/convert-to-json.sh) | Convert mysql database tables to json format |
