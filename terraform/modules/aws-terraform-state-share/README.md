Terraform module: Terraform state facility
==========================================

Ensures the existence of locations in which a Terraform state is stored and locked. It allows working in a collaborative
and distributed fashion on any kind of Terraform code.

It should be a one-time setup that doesn't need to be touched.

It makes use of the following AWS services:

* S3 bucket (Object Storage)
* DynamoDB (document-based Database)

The module can be used in the following way
```
module "initiate-tf-state-sharing" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-terraform-state-share"
  bucket_name = "myBucketName"
  table_name = "myTableName"
}
```

In order to destroy the previously created instance, one can

* use the AWS web console
* needs to import the existing state before, like
```
terraform import \
    -var 'bucket_name=${myStateBucketName}' \
    -var 'table_name=${myStateLockTableName}' \
    module.${myModuleInstanceName}.aws_s3_bucket.terraform-state-storage \
    ${myStateBucketName}
```

More documentation here:

* https://medium.com/@jessgreb01/how-to-terraform-locking-state-in-s3-2dc9a5665cb6
* https://www.terraform.io/docs/backends/types/s3.html
