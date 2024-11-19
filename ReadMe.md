# PRSDB - Infrastructure

This repository contains the Terraform configuration for the infrastructure of the Private Rented Sector Database (PRSDB) service. The main respository for the service, which includes Architecture Decision Records for this infrastructure can be found at https://github.com/communitiesuk/prsdb-webapp

## Setting up terraform

TODO

## Setting up a new environment from scratch

### Bootstrapping the terraform backend

- Create the new folder `terraform/<environment name>` and copy the contents of `terraform/environment_template` into it
- In `terraform/<environment name>/backend` remove the `.template` from the end of the file name and replace all instances of the string `<environment name>` with your actual environment name.
- Leave the block that starts with `backend "s3"` near the top of the file commented out
- `cd` into `terraform/<environment name>/backend` and run `terraform init` followed by `terraform plan`. Among other things the plan should show the creation of an s3 bucket called `prsdb-tfstate-<environment name>` and a dynamoDB table named `tfstate-lock-<environment name>`. If everything looks correct with the plan output, run `terraform apply`.
- After the `apply` step completes successfully and you can see the s3 bucket and dynamoDB table in the aws console, uncomment the `backend "s3"` block and run `terraform init`
- You should be prompted to move the terraform state to the remote backend. Once this is done the terraform state is successfully bootstrapped for the new environment

TODO: Add remaining instructions for setting up a new environment

## tfsec

This repository uses [tfsec](https://aquasecurity.github.io/tfsec/) to scan the Terraform code for potential security issues.
It can be run using Docker

```sh
docker run --pull=always --rm -it -v "$(pwd):/src" aquasec/tfsec /src
```

Individual rules can be ignored with a comment on the line above with the form `tfsec:ignore:<rule-name>`
e.g. `tfsec:ignore:aws-dynamodb-enable-at-rest-encryption`.