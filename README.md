# states-redactor

## Overview

The Firefly states redactor is a self hosted Kubernetes CronJob that fetches terraform state files from a remote source to a S3 bucket.
State files can contain sevsitive data, as a result the redactor reads the state files, identifies the sensitive data and replaces it.
The supported remote services:
| **Service**           | **Authentication**                                                | **Notes**                                                                                                                                  |
|-----------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| Terraform Cloud (tfc) | Use `tfcToken` in the `values.yaml` under `credentials`    | If using terraform enterprise, add the `tfcCustomDomain` under `credentials` or add the `address` under `firefly.location.tfc`. The address must start with `http://` ot `https://`. Token can be either an organization token or teams token (for the specified workspaces). |
| ArgoCD (argocd)       | Use `argocdToken` in the `values.yaml` under `credentials` | Add the `argocdDomain` under `credentials`. Token is a token of read-only argoCD user with apiKey capabilities. |

The redaction is for the following terraform providers (`Sensitive` attributes):

:white_check_mark: [AWS](https://registry.terraform.io/providers/hashicorp/aws)

:white_check_mark: [Google Cloud](https://registry.terraform.io/providers/hashicorp/google)

:white_check_mark: [Kubernetes](https://registry.terraform.io/providers/hashicorp/google)

:white_check_mark: [Datadog](https://registry.terraform.io/providers/DataDog/datadog)

:white_check_mark: [New Relic](https://registry.terraform.io/providers/newrelic/newrelic)

:white_check_mark: [Akamai](https://registry.terraform.io/providers/akamai/akamai)

:white_check_mark: [Github](https://registry.terraform.io/providers/integrations/github)

:white_check_mark: [Okta](https://registry.terraform.io/providers/okta/okta)

**In any case**, the redactor uses [Gitleaks](https://github.com/zricethezav/gitleaks) on every resource in order to enhance and make sure no secrets being written to mirror S3 bucket.

## Architecture
<img width="721" alt="image" src="https://github.com/user-attachments/assets/1a6c9195-731f-47ee-90e8-f9e6b696e66d">



The CronJob runs every 2 hours by default. The CronJob is designed to run on an EKS cluster since it relays on the `eks.amazonaws.com/role-arn` annotation. The role must have an OpenID trust relationship and must grant:
* s3:GetBucket - for target bucket
* s3:ListBucket - to list objects under the target bucket
* s3:GetObject - to get object (suffixes: `.tfstate`, `.jsonl`)
* s3:PutObject - to put new object (suffixes: `.tfstate`, `.jsonl`)
* (Optional) kms:Decrypt - if the bucket is encrypted.

## Quick Start

Run the following command
```bash
helm repo add firefly-redactor https://gofireflyio.github.io/states-redactor
helm install states-redactor firefly-redactor/firefly-redactor -f values.yaml --namespace=firefly --create-namespace
```

An example of `values.yaml` for S3 bucket:
```yaml
serviceAccount:
  annotations: {
     "gofirefly.io/component": firefly-redactor,
     "eks.amazonaws.com/role-arn": aws:aws:iam::123456789:role/my-role
  }
firefly:
  accountId: GIVEN-BY-FIREFLY
  crawlerId: GIVEN-BY-FIREFLY
  location:
    s3:
     isLocal: true
     bucket: my-bucket
     region: us-east-1
  type: s3

redactorMirrorBucketName: my-mirror-bucket
redactorMirrorBucketRegion: us-east-1
logging:
  remoteHash: GIVEN-BY-FIREFLY
```

An example of `values.yaml` for Terraform Cloud:
```yaml
serviceAccount:
  annotations: {
     "gofirefly.io/component": firefly-redactor,
     "eks.amazonaws.com/role-arn": aws:aws:iam::123456789:role/my-role
  }
firefly:
  accountId: GIVEN-BY-FIREFLY
  crawlerId: GIVEN-BY-FIREFLY
  location:
    tfc:
      organization: example
      address: example-tfc-enteprise.com
  type: tfc

credentials:
  tfcToken: MY-ORGANIZATION-TOKEN
  tfcCustomDomain: https://example-tfc-enteprise.com

redactorMirrorBucketName: my-mirror-bucket
redactorMirrorBucketRegion: us-east-1
logging:
  remoteHash: GIVEN-BY-FIREFLY
```

### Terraform ECS

This module call will create a task definition that will run the states-redactor on ECS Fargate periodically.
```
module "states-redactor-ecs" {
  source = "github.com/gofireflyio/states-redactor//terraform/ecs"
  aws_region = "us-west-2"

  firefly_account_id = "<ACCOUNT_ID>"             // Given by Firefly
  firefly_crawler_id = "<CRAWLER_ID>"             // Given by Firefly
  firefly_remote_log_hash = "<REMOTE_LOG_HASH>"   // Given by Firefly

  redacted_bucket_name = "tfstate-target-bucket"
  source_bucket_name = "tfstate-source-bucket"
  source_bucket_region = "us-west-2"

  container_cpu = 256
  container_memory = 512
  schedule_expression = "rate(2 hours)"

  security_groups = ["sg-1234"]
  subnets = ["subnet-1234", "subnet-5678"]
  assign_public_ip = false // If false, add VPC endpoints to reach the ECR
  ecs_cluster_arn = "arn:aws:ecs:us-west-2:0123456789:cluster/firefly-states-redactor" // If empty, will create a cluster
}
```
