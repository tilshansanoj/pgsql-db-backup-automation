## Requirements

- AWS CLI configured with proper S3 permissions
- PostgreSQL client tools (`pg_dump`, `pg_dumpall`) installed
- Network access between your server and PostgreSQL/S3


## How to Use This Script

1. **Save the script** as `pg_backup_to_s3.sh`.
2. **Make it executable**:
    ```sh
    chmod +x pg_backup_to_s3.sh
    ```
3. **Run it with your parameters:**

    - **Single database backup:**
      ```sh
      ./pg_backup_to_s3.sh -u postgres -h db.example.com -d mydatabase -b my-backup-bucket
      ```

    - **All databases backup:**
      ```sh
      ./pg_backup_to_s3.sh -u postgres -h db.example.com -a -b my-backup-bucket
      ```

    - **With password:**
      ```sh
      ./pg_backup_to_s3.sh -u postgres -h db.example.com -d mydatabase -b my-backup-bucket -p "secretpassword"
      ```

## Features

- Flexible argument parsing
- Validation of required parameters
- Support for both single database and all databases backup
- Optional password input
- Timestamp in filename for unique backups
- Success/failure feedback
- Proper cleanup of password environment variable

