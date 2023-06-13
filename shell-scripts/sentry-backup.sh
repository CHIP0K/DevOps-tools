#!/usr/bin/env bash
source /etc/environment

DOCKER_COMPOSE_FILE="/opt/docker/sentry/docker-compose.yml"
BACKUP_PATH="${HOME}/sentry-backup"
DATE_NOW="$(hostname)_$(date +"%d-%m-%Y-%R")"

NEXUS="true"
NEXUS_HOST="nexus.local.host"
NEXUS_DEPLOY_USER="deploy"
NEXUS_DEPLOY_PASSWORD="password"
CURL_HEADERS='Content-Type: multipart/form-data'

checkLock() {
  if [[ $(pgrep -fc "${0##*/}") -ne 1 ]]; then
    echo "Script ${0##*/} is running"
    exit 1
  fi
}

backupSentry() {
  docker-compose -f ${DOCKER_COMPOSE_FILE} \
    run -v "${BACKUP_PATH}":/sentry-data/backup \
    --rm -T \
    -e SENTRY_LOG_LEVEL=CRITICAL \
    web export /sentry-data/backup/"${DATE_NOW}"-sentry-backup.json
}

uploadToNexus() {
  curl -u "${NEXUS_DEPLOY_USER}:${NEXUS_DEPLOY_PASSWORD}" \
    -H "${CURL_HEADERS}" \
    --upload-file "${BACKUP_PATH}"/"${DATE_NOW}"-sentry-backup.json.gz \
    "https://${NEXUS_HOST}/repository/backups/sentry-backup/"
}

main() {
  checkLock
  [[ -d ${BACKUP_PATH} ]] || mkdir -p "${BACKUP_PATH}" && chmod a+w "${BACKUP_PATH}"
  if [[ -e ${DOCKER_COMPOSE_FILE} ]]; then
    backupSentry &>/dev/null                                  # Create backup
    gzip -9 "${BACKUP_PATH}"/"${DATE_NOW}"-sentry-backup.json # Compress backup
    if [[ ${NEXUS} = true ]]; then
      uploadToNexus # upload backup to nexus storage
    fi
  else
    echo "Docker-Compose file not fount"
    exit 1
  fi
}

main
