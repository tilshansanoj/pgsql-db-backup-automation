#!/bin/bash

# PostgreSQL to S3 Backup Script with Database-specific Folders
# Usage: ./pg_backup_to_s3.sh -u username -h hostname -d database_name -b s3_bucket [-a] [-p password]

# Initialize variables
BACKUP_ALL=false
PASSWORD=""

# Parse command line arguments
while getopts "u:h:d:b:p:a" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    h) HOSTNAME="$OPTARG" ;;
    d) DBNAME="$OPTARG" ;;
    b) BUCKET="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    a) BACKUP_ALL=true ;;
    *) echo "Usage: $0 -u username -h hostname [-d database_name | -a] -b s3_bucket [-p password]"
       exit 1 ;;
  esac
done

# Validate required arguments
if [ -z "$USERNAME" ] || [ -z "$HOSTNAME" ] || [ -z "$BUCKET" ]; then
  echo "Missing required arguments"
  echo "Usage: $0 -u username -h hostname [-d database_name | -a] -b s3_bucket [-p password]"
  exit 1
fi

# Validate either -d or -a is provided (but not both)
if [ -z "$DBNAME" ] && [ "$BACKUP_ALL" = false ]; then
  echo "You must specify either a database name (-d) or all databases (-a)"
  exit 1
fi

if [ -n "$DBNAME" ] && [ "$BACKUP_ALL" = true ]; then
  echo "You can't specify both a database name (-d) and all databases (-a)"
  exit 1
fi

# Set password if provided
if [ -n "$PASSWORD" ]; then
  export PGPASSWORD="$PASSWORD"
fi

# Create timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to backup a single database to its folder
backup_single_db() {
  local db=$1
  echo "Backing up database $db to S3..."
  FILENAME="backup_${TIMESTAMP}.sql.gz"
  S3_PATH="s3://${BUCKET}/backups/${db}/${FILENAME}"
  
  pg_dump -U "$USERNAME" -h "$HOSTNAME" "$db" | gzip | aws s3 cp - "$S3_PATH"
  
  if [ $? -eq 0 ]; then
    echo "Backup successful: $S3_PATH"
  else
    echo "Backup failed for database $db!"
    return 1
  fi
}

# Perform backup
if [ "$BACKUP_ALL" = true ]; then
  echo "Backing up ALL databases to S3..."
  
  # Get list of databases (excluding system databases)
  DATABASES=$(psql -U "$USERNAME" -h "$HOSTNAME" -t -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres';")
  
  for DB in $DATABASES; do
    backup_single_db "$DB"
    if [ $? -ne 0 ]; then
      echo "Error occurred during backup of all databases"
      exit 1
    fi
  done
else
  backup_single_db "$DBNAME"
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi

# Unset password if it was set
if [ -n "$PASSWORD" ]; then
  unset PGPASSWORD
fi