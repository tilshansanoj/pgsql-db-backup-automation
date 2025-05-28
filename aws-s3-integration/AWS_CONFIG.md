1. **Create an IAM Policy**

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

2. **S3 Bucket Permissions**

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

3. **Testing Permissions**

Test your setup with:

```bash
# Test S3 access
aws s3 ls s3://your-backup-bucket/

# Test PostgreSQL access
psql -U username -h hostname -c "\l"
```