## AWS

Install or update the latest version of the AWS CLI
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

### Configuration and credential file settings
Run this command to set your credentials, region, and output format. The following example shows sample values.
```shell
> aws configure --profile [YOUR_PROFILE]
AWS Access Key ID [None]: ******
AWS Secret Access Key [None]: ******
Default region name [None]: us-east-1
Default output format [None]: json
```

To list configuration data, use the aws configure list command.
```shell
> aws configure list
```

## Build solution
```shell
> dotnet build -c release
```

## Terraform

### Update profile
Replace the AWS PROFILE with your own in main.tf.
```json
provider "aws" {
  profile = "[YOUR_PROFILE]"
  region = "us-east-1"
}
```

### Init
```shell
> terraform init
```

### Apply
Replace the SNS email address with your own in variables.tf.
```json
variable "sns_email" {
  type    = string
   default = "[YOUR_EMAIL]"
}
```

```shell
> terraform apply
```

After the Terraform plan execution is complete, look for the outputs to test your API.

Outputs:

- lambda_function_url = "https://<url_id>.lambda-url.<region>.on.aws/"
- s3_bucket_name = "ei-bg-api-file-upload"

AWS will send you an email to confirm your subscription to SNS. Click the link in the email to confirm your email address and receive notifications when files are uploaded.

### Destroy

Before destroying, you must remove the uploaded images from the S3 bucket, as AWS policy prohibits deleting non-empty buckets.

You can either use the DeleteFiles endpoint or manually delete the files from the AWS console.

```shell
> terraform destroy
```


To Do:
- Upload zip to s3 vs from file system (3)
- terraform.tfstate is S3
- Clean up main.tf (seperate into modules) and update output.tf (1)

```
> git filter-branch -f --index-filter 'git rm --cached -r --ignore-unmatch .terraform/'
```