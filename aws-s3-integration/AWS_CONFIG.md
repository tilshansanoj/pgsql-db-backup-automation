## **Create an IAM Policy**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::your-backup-bucket",
                "arn:aws:s3:::your-backup-bucket/*"
            ]
        }
    ]
}
```

- Create an IAM role with this policy.
- Attach the role to your EC2 instance.

## **S3 Bucket Permissions**

Add this to your S3 bucket policy (replace placeholders):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:role/your-ec2-role"
            },
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::your-backup-bucket",
                "arn:aws:s3:::your-backup-bucket/*"
            ]
        }
    ]
}
```

## **Testing Permissions**

Test your setup with:

```bash
# Test S3 access
aws s3 ls s3://your-backup-bucket/

# Test PostgreSQL access
psql -U username -h hostname -c "\l"
```

## **Add a S3 Bucket Lifecycle Rule**

To automatically delete backups older than 30 days, you can set up a lifecycle rule in your S3 bucket. This can be done using the AWS CLI as follows:
```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket wireapps-internal-postgres-db-backups \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "Delete30DayOldBackups",
        "Status": "Enabled",
        "Filter": {
          "Prefix": "backups/"
        },
        "Expiration": {
          "Days": 30
        }
      }
    ]
  }
```