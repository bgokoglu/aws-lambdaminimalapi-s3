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
Update AWS profile name in the main.tf
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
```shell
> terraform apply
```

After terraform plan execution is complete look for the outputs to test your API.

Outputs:

- lambda_function_url = "https://<url_id>.lambda-url.<region>.on.aws/"
- s3_bucket_name = "ei-bg-api-file-upload"

### Destroy

Before destroying, you must remove the uploaded images from the S3 bucket, as AWS policy prohibits deleting buckets that are not empty.

You can either use the DeleteFiles endpoint or manually delete the files in the AWS console.

```shell
> terraform destroy
```
