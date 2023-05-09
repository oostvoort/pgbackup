FROM debian:buster-slim AS cron

RUN apt-get update && apt-get -y upgrade && apt-get -y install cron

CMD ["/bin/sh", "-c", "printenv > /etc/environment && touch /etc/cron.d/crontab && crontab /etc/cron.d/crontab && chmod -R 0644 /etc/cron.d && cron && sh -c \"touch /var/log/cron.log && tail -f /var/log/cron.log\""]

FROM cron as backup

# Prepare apt
RUN apt-get install -y gnupg

# Install s3cmd from backports
RUN sh -c 'echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list.d/backports.list'
RUN apt-get update && apt-get install -y s3cmd/buster-backports

# Install deps
RUN apt-get -y install \
    tzdata \
    openssl \
    wget \
    lsb-release \
    netcat \
    curl

# Create the file repository configuration:
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Import the repository signing key:
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Update the package lists:
RUN apt-get update

# Install the specific version of the postgres-client. Default to 15 if not given.
ARG POSTGRES_VERSION=15
RUN apt-get -y install postgresql-client-$POSTGRES_VERSION

# To keep image small, clear apt lists
RUN apt-get clean

# Set defaults for environment vars
ENV UID=65534 \
    GID=65534 \
    POSTGRES_DB="**None**" \
    POSTGRES_HOST="**None**" \
    POSTGRES_PORT=5432 \
    POSTGRES_USER="**None**" \
    POSTGRES_PASSWORD="**None**" \
    POSTGRES_EXTRA_OPTS="" \
    POSTGRES_CLUSTER="FALSE" \
    BACKUP_CRON="0 0 * * *" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".backup" \
    BACKUP_ENCRYPTION_KEY="" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    BACKUP_KEEP_MINS=1440 \
    WEBHOOK_URL="**None**" \
    WEBHOOK_EXTRA_ARGS="" \
    S3_ACCESSKEY=""     \
    S3_SECRET=""     \
    S3_HOST_BASE=""     \
    S3_HOST_BUCKET=""     \
    RESTORE_ONCE=""     \
    BACKUP_ONSTART=""

# Copy the scripts
COPY *.sh /

# Enable loading of environment and functions upon shell login
RUN sh -c 'echo "source /etc/environment" >> /root/.bashrc'
RUN sh -c 'echo "source /backup.sh" >> /root/.bashrc'
RUN sh -c 'echo "source /restore.sh" >> /root/.bashrc'

# Register the healthcheck which will monitor accessibility of the postgres target
HEALTHCHECK --start-period=20s --interval=1m --timeout=1s --retries=500 \
  CMD pg_isready -U $POSTGRES_USER -h $POSTGRES_HOST -t 0 || exit 1

# Register the volume where the backups are kept
VOLUME ["/backups"]

# Run the main script, this will end with tailing /var/log/cron.log
CMD ["/run.sh"]



