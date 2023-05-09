#!/bin/bash
set -Eeo pipefail

source /root/.bashrc

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  echo "You need to set the POSTGRES_HOST environment variable."
  exit 1
fi

if [ "${POSTGRES_DB}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DB variable."
  exit 1
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD variable."
  exit 1
fi


# Set some useful environment vars for pg_restore and pg_dump
export PGHOST=${POSTGRES_HOST}
export PGPORT=${POSTGRES_PORT}
export PGUSER=${POSTGRES_USER}
export PGPASSWORD="${POSTGRES_PASSWORD}"

# Write the environment (with some trick to quote the complex vars)
printenv | sed 's/\(^[^=]*\)=\(.*\)/export \1="\2"/' > /etc/environment



# Write the cron schedule
rm -f /etc/crontab
cat <<EOF >> /etc/crontab
SHELL=/bin/bash
${BACKUP_CRON} root . /root/.bashrc; backup >> /var/log/cron.log
# this line is supposed to be here
EOF


# Write the s3config
rm -f /root/.s3cfg
cat <<EOF >> /root/.s3cfg
[default]
access_key = ${S3_ACCESSKEY}
secret_key = ${S3_SECRET}
host_base = ${S3_HOST_BASE}
host_bucket = ${S3_HOST_BUCKET}
signature_v2 = False
use_https = True
EOF


if [ -n "${RESTORE_ONCE}" ]; then
  until nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"
  do
      echo "waiting for database container..."
      sleep 1
  done
  restore ${RESTORE_ONCE}

  echo "RESTORE_ONCE used: pgbackup will NOT schedule backups anymore, clear RESTORE_ONCE and restart container resume normal operation."

  # TODO make this more elegant
  # Overwrite the crontab so its not scheduling anything
  rm -f /etc/crontab
  cat <<EOF >> /etc/crontab
  # this line is supposed to be here
EOF
  touch /var/log/cron.log
  tail -f /var/log/cron.log
fi


if [ -n "${BACKUP_ONSTART}" ] && [ -z "${RESTORE_ONCE}" ]; then
    echo "=> Create a backup immediately"

    if ! backup ; then
      # TODO make this more elegant
      # Overwrite the crontab so its not scheduling anything
      rm -f /etc/crontab
      cat <<EOF >> /etc/crontab
      # this line is supposed to be here
EOF
      echo "Initial backup failed, not scheduling cron. Please fix settings to resolve."
      touch /var/log/cron.log && tail -f /var/log/cron.log
    fi
fi

# Schedule and run the crontab
echo "Enabling cron with schedule \"${BACKUP_CRON}\""
crontab /etc/crontab
chmod -R 0644 /etc/cron.d
cron

echo "pgbackup activated!"

# Stay alive on the tail of the cron log
touch /var/log/cron.log
tail -f /var/log/cron.log
