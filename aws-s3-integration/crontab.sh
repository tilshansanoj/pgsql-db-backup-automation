0 2 * * * /path/to/pg_backup_to-s3.sh  -u username -h db.hostname  -a -b s3_bucket_name -p password >> ~/backup_logs/pg_backup_$(date +\%Y\%m\%d).log 2>&
