#!/bin/bash

# PostgreSQL to Azure Blob Storage Backup Script with Robust SAS Handling
# Usage: ./pg_backup_to_azure.sh -u username -h hostname [-d database_name | -a] -c container_name -s "SAS_TOKEN"

# Initialize variables
BACKUP_ALL=false
PASSWORD=""
SAS_TOKEN=""
ACCOUNT_NAME=""

# Parse arguments
while getopts "u:h:d:c:p:a:s:" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    h) HOSTNAME="$OPTARG" ;;
    d) DBNAME="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    a) BACKUP_ALL=true ;;
    s) SAS_TOKEN="$OPTARG" ;;
    *) echo "Usage: $0 -u username -h hostname [-d database_name | -a] -c container_name -s \"SAS_TOKEN\""
       exit 1 ;;
  esac
done

# Validate arguments
[ -z "$USERNAME" ] || [ -z "$HOSTNAME" ] || [ -z "$CONTAINER" ] || [ -z "$SAS_TOKEN" ] && {
  echo "Missing required arguments"
  exit 1
}

# Extract account name from SAS token if in URL format
if [[ "$SAS_TOKEN" == *"blob.core.windows.net"* ]]; then
  ACCOUNT_NAME=$(echo "$SAS_TOKEN" | awk -F'/' '{print $3}' | awk -F'.' '{print $1}')
  SAS_TOKEN=$(echo "$SAS_TOKEN" | awk -F'?' '{print $2}')
fi

[ -z "$ACCOUNT_NAME" ] && {
  echo "Could not extract storage account name from SAS token"
  echo "Please provide either:"
  echo "1. Full SAS URL (https://account.blob.core.windows.net?sv=...)"
  echo "2. Account name via -a parameter and SAS token via -s"
  exit 1
}

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
  local dest_url="https://${ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER}/${blob_path}?${SAS_TOKEN}"
  
  echo "Streaming backup of $db to Azure..."
  echo "Destination URL: ${dest_url%%sig=*}sig=***REDACTED***"
  
  # Start AzCopy in the background
  azcopy copy "$PIPE" "$dest_url" \
    --recursive=false \
    --log-level=ERROR \
    --put-md5 
    --output-type=quiet \
    --overwrite=true \
    --from-to=pipe-blob &
  local azcopy_pid=$!
  
  # Stream PostgreSQL backup through gzip to AzCopy
  pg_dump -U "$USERNAME" -h "$HOSTNAME" "$db" | gzip > "$PIPE"


  wait $azcopy_pid
  local status=$?
  
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