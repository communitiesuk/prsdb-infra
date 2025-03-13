# PRSDB - Infrastructure

This repository contains the Terraform configuration for the infrastructure of the Private Rented Sector Database (PRSDB) service. The main respository for the service, which includes Architecture Decision Records for this infrastructure can be found at https://github.com/communitiesuk/prsdb-webapp

## Setting up terraform

Install the appropriate version of Terraform by following [these instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli). We are currently using 1.9.x, so make sure you select that version. 
If using the "Manual installation" method, you can select the correct version from the dropdown at the top of the installation page.

Install the latest AWS vault by following [these instructions](https://github.com/99designs/aws-vault). (N.B. there is no windows AMD64 version, so you need to use 386 in that case). 
You will need to rename the .exe file to "aws-vault.exe" and add it to your path.

Install AWS CLI by following [these instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

Use the shell script "setup/create_profiles.sh" to add a `.aws/config` file to your home directory, with your mfa_serial value added.
You can find this in the aws console under the top right drop down menu -> `Security credentials".
You should not override the destination file.

```shell
setup/create_profiles.sh "Your mfa_serial value" ["Override destination file"]
```

Create an access key in the AWS portal on the Security credentials page (just below where you found you `mfa_serial`). In your terminal, run `aws-vault add mhclg` and provide your access key details.

In your terminal, navigate to the integration directory and run `aws-vault exec mhclg-int -- <your preferred shell>`. 
This will start a sub-shell with the access key credentials available and the role of that profile. Use `exit` to return to your previous shell when you are done.
If you want to work on a different environment, instead navigate to that environment's directory and use the corresponding profile instead of `mhclg-int`.

Still in the environment directory, run `terraform init` to create a local terraform state linking to the shared environment state.

You are now ready to start running terraform commands on the chosen environment.

## Accessing deployed infrastructure

### Connecting to the database
The database is an RDS instance running on isolated subnets. This means there is no way to directly connect to it. 
Instead, we use one bastion EC2 instance per availability zone acting as an 
[SSM agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html). 
The instructions here assume that all infrastructure is deployed in the region eu-west-2 (London). 
If the infrastructure is in a different region, use that instead in each link and command.

Once you have followed the set up above, to connect to the database you will need:
* The id of bastion you intend to use - [london ec2 instances](https://eu-west-2.console.aws.amazon.com/ec2/home#Instances)
* The endpoint of the database - [london databases](https://eu-west-2.console.aws.amazon.com/rds#databases:)
* The password for the database is stored in secrets - [london secrets](https://eu-west-2.console.aws.amazon.com/secretsmanager/listsecrets)

First, start an `aws-vault exec` session for the profile corresponding to the environment you want to connect to,
then run this command:

```shell
aws ssm start-session --region eu-west-2 --target <bastion id> --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host="<database endpoint>",portNumber="5432",localPortNumber="5432"
```

You should see something similar to:
```shell 
Starting session with SessionId: 12a3456bcdefghi789
Port 5432 opened for sessionId 12a3456bcdefghi789.
Waiting for connections...
```

Leave this terminal open and running, and then you should be able to connect to the database from your machine using 
this connection string:
```
postgresql://postgres:<password>@localhost:5432/prsdb
```

When you start a connection, you will see a confirmation in the terminal window:
```shell
Connection accepted for session [12a3456bcdefghi789]
```

## Setting up a new environment from scratch

### Bootstrapping the terraform backend

- Create the new folder `terraform/<environment name>` and copy the contents of `terraform/environment_template` into it
- In `terraform/<environment name>/backend` remove the `.template` from the end of the file name and replace all instances of the string `<environment name>` with your actual environment name.
- Leave the block that starts with `backend "s3"` near the top of the file commented out
- `cd` into `terraform/<environment name>/backend` and run `terraform init` followed by `terraform plan`. Among other things the plan should show the creation of an s3 bucket called `prsdb-tfstate-<environment name>` and a dynamoDB table named `tfstate-lock-<environment name>`. If everything looks correct with the plan output, run `terraform apply`.
- After the `apply` step completes successfully and you can see the s3 bucket and dynamoDB table in the aws console, uncomment the `backend "s3"` block and run `terraform init`
- You should be prompted to move the terraform state to the remote backend. Once this is done the terraform state is successfully bootstrapped for the new environment

### Setting up the environment folder

- In your new `terraform/<environment name>` folder, you can now also remove the `.template` from the end of all of the filenames, replace all instances of the string `<environment name>` with your actual environment name, and more generally look through `main.tf` for any sets of `<>` that require environment-specific input, e.g. the domains of any 3rd party integrations.

### Setting up the initial networking and requesting the ssl certificates

- Before we can create the environment as a whole, we must first create the initial networking infrastructure, and then request the DNS names and certificates from MHCLG.
- One of the files in your new `terraform/<environment name>` folder will be `terraform.tfvars`. Check that this contains the line `ssl_certs_created = false`
- Once this is done, `cd` into `terraform/<environment name>` and run `terraform init` followed by `terraform plan -target module.networking -target module.frontdoor`. If the output of the plan looks correct, run `terraform apply -target module.networking -target module.frontdoor` to bring up the networking and ECR repository for the new environment.
- Use the values in the terraform output to complete the request to MHCLG for changes to their DNS records

### Requesting DNS changes from MHCLG

- Use the terraform output to complete a copy of the 'DNS Change Request Form -v2.xlsx' file in the root of the repository as follows:
  - For each item in the `cloudfront_certificate_validation` and `load_balancer_certificate_validation` blocks of the output:
    - add a row to the table where:
      - 'Change' Type is 'Add'
      - 'Requested by' is your name
      - 'Record Type' is the value from `resource_record_type`
      - 'Domain' is either `test.communities.gov.uk` or `service.gov.uk`, whichever appears as part of the value in `domain_name`
      - 'Name' is the value from `resource_record_name`
      - 'Content' is the value from `resource_record_value`
      - 'TTL' is '1 hr'
      - 'Proxy status' is 'DNS only'
      - 'Additional comment or Reason for this change' is 'Setting up <environment name> environment for the PRS Database'
  - For each item in the `cloudfront_certificate_validation` block of the output add an additional row to the table where:
    - 'Change' Type is 'Add'
    - 'Requested by' is your name
    - 'Record Type' is 'CNAME'
    - 'Domain' is either `test.communities.gov.uk` or `service.gov.uk`, whichever appears as part of the value in `domain_name`
    - 'Name' is the value from `domain name`
    - 'Content' is the value from `cloudfront_dns_name`
    - 'TTL' is '1 hr'
    - 'Proxy status' is 'DNS only'
    - 'Additional comment or Reason for this change' is 'Setting up <environment name> environment for the PRS Database'
  - For each item in the `load_balancer_certificate_validation` block of the output add an additional row to the table where:
    - 'Change' Type is 'Add'
    - 'Requested by' is your name
    - 'Record Type' is 'CNAME'
    - 'Domain' is either `test.communities.gov.uk` or `service.gov.uk`, whichever appears as part of the value in `domain_name`
    - 'Name' is the value from `domain name`
    - 'Content' is the value from `load_balancer_dns_name`
    - 'TTL' is '1 hr'
    - 'Proxy status' is 'DNS only'
    - 'Additional comment or Reason for this change' is 'Setting up <environment name> environment for the PRS Database'

- Once the spreadsheet is completed, create a service now request with MHCLG using the general 'Request' option with the following details:
  - 'What is it that you require?' --> "Creation of DNS records"
  - 'Why do you require it?' --> "We are setting up the <environment name> environment for the new PRS Database in AWS. As part of this we need DNS records for the sub-domains and associated certificates. These subdomains were approved by TDA on 21/08/24. The service owner for the project is <service owner name>."
  - And add the completed spreadsheet as an attachment to the request

### Setting up pre-requisite resource, and task definition

- We also need to create a number of pre-requisite resources, and then initial task definition before we can bring up the full ECS service.
- Make sure that the `terraform.tfvars` file that was created in the previous step contains the line `task_definition_created = false`
- Still inside your `terraform/<environment name>` folder, run `terraform plan`.
- If the output of the plan looks correct, run `terraform apply` to create the pre-requisite resources.
- Terraform will create the webapp secrets and SSM parameters but (apart from those related to the database and Redis) will not populate them. Ask the team lead where you can find the appropriate values, and then populate them via the AWS console.
- To create the task definition, in `terraform/<environment name>/ecs_task_definition`, if you haven't already, remove the `.template` from the end of any file names in the folder, and replace all instances of the string `<environment name>` with your actual environment name.
- Next, cd into `terraform/<environment name>/ecs_task_definition` and run `terraform init` followed by `terraform plan`. This should show you one resource being created - the task definition. If the output looks correct, run `terraform apply`.

### Setting up the rest of the environment

- In `terraform.tfvars` set `ssl_certs_created` to `true` and `task_definition_created` to `true`.
- Then run `terraform plan`. If the output looks correct, run `terraform apply` to bring up the environment.

## tfsec

This repository uses [tfsec](https://aquasecurity.github.io/tfsec/) to scan the Terraform code for potential security issues.
It can be run using Docker

```sh
docker run --pull=always --rm -it -v "$(pwd):/src" aquasec/tfsec /src
```

Individual rules can be ignored with a comment on the line above with the form `tfsec:ignore:<rule-name>`
e.g. `tfsec:ignore:aws-dynamodb-enable-at-rest-encryption`.