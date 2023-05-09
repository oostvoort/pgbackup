#!/usr/bin/env bash
set -Eeo pipefail
function restore()
{
  export PGHOST=${POSTGRES_HOST}
  export PGPORT=${POSTGRES_PORT}
  export PGUSER=${POSTGRES_USER}
  export PGPASSWORD="${POSTGRES_PASSWORD}"

  # TODO test if file exists
  if [ ! -s $1 ]; then
    echo "${1} is empty or does not exist!"
    echo "   Restore failed"
    return
  fi

  RESTORE_FILE=/tmp/restore.gz

  echo "=> Restore database from $1"

  if [ -n "${BACKUP_ENCRYPTION_KEY}" ] ; then
    # decrypt
    echo "Decrypting"
    openssl enc -d -aes256 -md sha256 -pbkdf2 -pass env:BACKUP_ENCRYPTION_KEY -in $1 -out $RESTORE_FILE
    echo "Done decrypt"
    if [ $? -ne 0  ] ;then
      rm -f $RESTORE_FILE
      echo "   Decryption failed: ${$1}"
      return
    fi
  else
    # Just rename the input file to the tmp
    cp $1 $RESTORE_FILE
  fi

  # Kick out users from the database being restored
  psql -d template1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${POSTGRES_DB}';"

  # Restore the db. NOTE: this relies on the existence of the "template1" database
  cat $RESTORE_FILE | gunzip | psql -d template1

  if [ $? -eq 0  ] ;then
      echo "   Restore succeeded"
      rm -f $RESTORE_FILE
  else
      echo "   Restore failed"
      rm -f $RESTORE_FILE
      return
  fi
  echo "=> Done"
}