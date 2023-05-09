#!/usr/bin/env bash
set -Eeo pipefail

function backup()
{
  # TODO: Hooks
  #HOOKS_DIR="/hooks"
  #if [ -d "${HOOKS_DIR}" ]; then
  #  on_error(){
  #    run-parts -a "error" "${HOOKS_DIR}"
  #  }
  #  trap 'on_error' ERR
  #fi

  # TODO: Pre-backup hook
  #if [ -d "${HOOKS_DIR}" ]; then
  #  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
  #fi

  KEEP_MINS=${BACKUP_KEEP_MINS}
  KEEP_DAYS=${BACKUP_KEEP_DAYS}
  KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
  KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`


  #Initialize dirs
  mkdir -p "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

  # Re-export postgres env variables so pg_dump can read them (this makes the command cleaner to read here)
  export PGHOST=${POSTGRES_HOST}
  export PGPORT=${POSTGRES_PORT}
  export PGUSER=${POSTGRES_USER}
  export PGPASSWORD="${POSTGRES_PASSWORD}"


  #Initialize filename vers
  LAST_FILENAME="${POSTGRES_DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
  DAILY_FILENAME="${POSTGRES_DB}-`date +%Y%m%d`${BACKUP_SUFFIX}"
  WEEKLY_FILENAME="${POSTGRES_DB}-`date +%G%V`${BACKUP_SUFFIX}"
  MONTHY_FILENAME="${POSTGRES_DB}-`date +%Y%m`${BACKUP_SUFFIX}"
  FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
  DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
  WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
  MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"


  TMPFILE=/tmp/latest.dump
  rm -f $TMPFILE
  #Create dump and immediately encrypt with openssl
  echo "Creating dump of database: ${POSTGRES_DB}, from host: ${POSTGRES_HOST}..."

  pg_dump --clean --create ${POSTGRES_EXTRA_OPTS} ${POSTGRES_DB} | gzip -9 > $TMPFILE


  if [ $? -ne 0  ] ;then
    rm -f $TMPFILE
    echo "   Backup failed: ${POSTGRES_DB}"
    return
  fi

  if [ -n "${BACKUP_ENCRYPTION_KEY}" ] ; then
    # Encrypt the tmpfile
    echo "Encrypting..."
    openssl enc -aes256 -md sha256 -pbkdf2 -pass env:BACKUP_ENCRYPTION_KEY -in $TMPFILE -out ${FILE}
    if [ $? -ne 0  ] ;then
      rm -f $TMPFILE
      echo "   Encryption failed: ${POSTGRES_DB}"
      return
    fi
  else
    # Just rename the tmpfile
    mv $TMPFILE ${FILE}
  fi


  echo "   Dump succeeded: ${POSTGRES_DB}"


  #Copy (hardlink) for each entry
  if [ -d "${FILE}" ]; then
    DFILENEW="${DFILE}-new"
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    ln -f "${FILE}/"* "${DFILENEW}/"
    ln -f "${FILE}/"* "${WFILENEW}/"
    ln -f "${FILE}/"* "${MFILENEW}/"
    rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
    echo "Replacing daily backup ${DFILE} folder this last backup..."
    mv "${DFILENEW}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} folder this last backup..."
    mv "${WFILENEW}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} folder this last backup..."
    mv "${MFILENEW}" "${MFILE}"
  else
    echo "Replacing daily backup ${DFILE} file this last backup..."
    ln -vf "${FILE}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} file this last backup..."
    ln -vf "${FILE}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} file this last backup..."
    ln -vf "${FILE}" "${MFILE}"
  fi

  # Update latest symlinks
  echo "Point last backup file to this last backup..."
  ln -svf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${POSTGRES_DB}-latest${BACKUP_SUFFIX}"
  echo "Point latest daily backup to this last backup..."
  ln -svf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${POSTGRES_DB}-latest${BACKUP_SUFFIX}"
  echo "Point latest weekly backup to this last backup..."
  ln -svf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${POSTGRES_DB}-latest${BACKUP_SUFFIX}"
  echo "Point latest monthly backup to this last backup..."
  ln -svf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${POSTGRES_DB}-latest${BACKUP_SUFFIX}"

  #Clean old files
  echo "Cleaning older files for ${POSTGRES_DB} database from ${POSTGRES_HOST}..."
  find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${POSTGRES_DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${POSTGRES_DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${POSTGRES_DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${POSTGRES_DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'

  echo "SQL backup created successfully"

  # Sync s3
  if [ -n "${S3_BUCKET}" ]; then
    echo "Sync archives to S3"
    s3cmd -v sync ${BACKUP_DIR}/* "s3://${S3_BUCKET}/${S3_DIR}/" --skip-existing || return 20
  fi


  # TODO: Test and finish
  #if [ -n "${SSH_HOST}" ]; then
  #  echo "Sync archives to sftp"
  #  cd $BACKUPS_DIR
  #  find . -name '*.psql.gz' -exec curl -v --insecure -T '{}' "sftp://${SSH_USER}:${SSH_PASS}@${SSH_HOST}/${SSH_PATH}/"'{}' \;
  #fi


  # TODO: Post-backup hook
  #if [ -d "${HOOKS_DIR}" ]; then
  #  run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
  #fi
}