#!/bin/bash

# PostgreSQL to Azure Blob Storage Backup Script with Streaming
# Usage: ./pg_backup_to_azure.sh -u username -h hostname [-d database_name | -a] -c container_name -s "SAS_URL" [-p password]

# Initialize variables
BACKUP_ALL=false
PASSWORD=""
SAS_URL=""

# Parse arguments
while getopts "u:h:d:c:p:a:s:" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    h) HOSTNAME="$OPTARG" ;;
    d) DBNAME="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    a) BACKUP_ALL=true ;;
    s) SAS_URL="$OPTARG" ;;
    *) echo "Usage: $0 -u username -h hostname [-d database_name | -a] -c container_name -s \"SAS_URL\" [-p password]"
       exit 1 ;;
  esac
done

# Validate arguments
[ -z "$USERNAME" ] || [ -z "$HOSTNAME" ] || [ -z "$CONTAINER" ] || [ -z "$SAS_URL" ] && {
  echo "Missing required arguments"
  exit 1
}

# Check AzCopy
if ! command -v azcopy &> /dev/null; then
  echo "Installing AzCopy..."
  curl -sL https://aka.ms/downloadazcopy-v10-linux | tar xz --strip-components=1 -C /usr/local/bin/ --wildcards '*/azcopy'
fi

# Set password if provided
[ -n "$PASSWORD" ] && export PGPASSWORD="$PASSWORD"

# Create pipe for streaming
PIPE=$(mktemp -u /tmp/pg_backup_pipe.XXXXXX)
mkfifo "$PIPE"
trap 'rm -f "$PIPE"' EXIT

# Streaming backup function
stream_backup() {
  local db=$1
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local blob_path="${db}/backup_${timestamp}.sql.gz"
  
  echo "Streaming backup of $db to Azure..."
  
  # Start AzCopy in the background
  azcopy copy "$PIPE" "${SAS_URL%/}/$CONTAINER/$blob_path" \
    --recursive=false \
    --log-level=ERROR &
  
  # Stream PostgreSQL backup through gzip to AzCopy
  pg_dump -U "$USERNAME" -h "$HOSTNAME" "$db" | gzip > "$PIPE"
  
  wait # for AzCopy to finish
  [ $? -eq 0 ] && echo "Backup successful: $blob_path" || {
    echo "Backup failed for $db"
    return 1
  }
}

# Main execution
if [ "$BACKUP_ALL" = true ]; then
  echo "Backing up ALL databases..."
  DATABASES=$(psql -U "$USERNAME" -h "$HOSTNAME" -d postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres' AND datname != 'rdsadmin';")
  
  for DB in $DATABASES; do
    stream_backup "$DB" || exit 1
  done
else
  stream_backup "$DBNAME" || exit 1
fi

# Cleanup
[ -n "$PASSWORD" ] && unset PGPASSWORD