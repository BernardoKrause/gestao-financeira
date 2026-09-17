#!/usr/bin/env bash
set -euo pipefail

CONTAINER="gestao_financeira_mvp-db"
DB_NAME="gestao_financeira_mvp_production"
DB_USER="gestao_financeira_mvp"
BACKUP_DIR="/var/backups/postgres"
RCLONE_REMOTE="oci-backup:gestao-financeira-backups"
RETENTION_DAYS=14
ENV_FILE="/root/.backup-env"

# shellcheck source=/dev/null
source "$ENV_FILE"

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" \
  pg_dump -U "$DB_USER" -Fc "$DB_NAME" > "$DUMP_FILE"

rclone copy "$DUMP_FILE" "$RCLONE_REMOTE" --no-traverse

find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -mtime +"$RETENTION_DAYS" -delete
rclone delete "$RCLONE_REMOTE" --min-age "${RETENTION_DAYS}d"
