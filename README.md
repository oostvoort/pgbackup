# Overview
- Docker container that can backup postgres containers to a mounted /backups volume
- Rotates the backups
- Optional:
  - Can encrypt the backups
  - Syncs the backups to s3-compatible storage

# How to use
## Docker-compose
Sample `docker-compose.yml`: 
```yaml
version: "3.9"

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
      POSTGRES_INITDB_ARGS: ""
  pgbackup:
    image: "oostvoort/pgbackup:15-latest"
    environment:
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
      POSTGRES_DB: "postgres"
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_EXTRA_OPTS: "--blobs"
      BACKUP_CRON: "* * * * *"
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6
      BACKUP_ENCRYPTION_KEY: "INSECURE"
      S3_HOST_BASE: "sgp1.digitaloceanspaces.com"
      S3_HOST_BUCKET: "%(bucket)s.sgp1.digitaloceanspaces.com"
      S3_BUCKET: "mybucket"
      S3_DIR: "mydir"
      S3_ACCESSKEY: "ACCESSKEY"
      S3_SECRET: "SECRET"
      BACKUP_ONSTART: "1"
      RESTORE_ONCE: ""

```
## Caprover
Right now pgbackup is not yet included in the official 1-click apps. You can install it in your caprover by choosing the "template" 1-click app, and then pasting the following: 
```yaml
captainVersion: 4
services:
  '$$cap_appname':
    image: oostvoort/pgbackup:$$cap_version
    environment:
      POSTGRES_HOST: srv-captain--pgtest
      POSTGRES_PORT: 5432
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      BACKUP_CRON: "* * * * *"
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6
      BACKUP_ENCRYPTION_KEY: "insecure"
      S3_HOST_BASE: sgp1.digitaloceanspaces.com
      S3_HOST_BUCKET: "%(bucket)s.sgp1.digitaloceanspaces.com"
      S3_BUCKET: postgres-backup
      S3_DIR: test
      S3_ACCESSKEY: insecure_key
      S3_SECRET: insecure_secret
      RESTORE_ONCE: ""
      BACKUP_ONSTART: "1"
    volumes:
      - '$$cap_appname-data:/backups'
    restart: no
caproverOneClickApp:
  variables:
    - id: '$$cap_version'
      label: pgbackup version
      defaultValue: '15-latest'
      description: 'Check out: https://hub.docker.com/repository/docker/oostvoort/pgbackup/tags'
      validRegex: "/^([^\\s^\\/])+$/"
  instructions:
    start: |-
      Docker sidecar container that can backup/restore a Postgres database container. Additionally supports rotation of backup files, encryption of the backup files and sync to s3-compatible storage.
      
      More details: https://hub.docker.com/repository/docker/oostvoort/pgbackup/general
    end: |-
      pgbackup has been successfully deployed!
  displayName: pgbackup
  isOfficial: true
  description: "Docker sidecar container that can backup/restore a Postgres database container. Additionally supports rotation of backup files, encryption of the backup files and sync to s3-compatible storage."
  documentation: "See https://hub.docker.com/repository/docker/oostvoort/pgbackup"


```

# Notes
- If the "postgres" db is being restored, it needs the system db "template1" to be present and accessible.

# TODO
- Don't let the user restore the same file twice without doing some sort of conscious override. It's possible now that the restore succeeds and the operator forgets to re-enable the normal backup.
- Cleaner reporting in the stdout
- Maybe use the POSTGRES_HOST as the S3_DIR arg
- Also rotate (clean up old backups) on s3, this is probably not happening now

# Thanks
Pgbackup is based on 2 other repos:
  - https://github.com/alexanderczigler/docker-postgres-backup
  - https://github.com/prodrigestivill/docker-postgres-backup-local