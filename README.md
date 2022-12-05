# states-redactor

The Firefly states redactor is a self hosted Kubernetes CronJob that fetches terraform state files from a remote source to a S3 bucket.
State files can contain sevsitive data, as a result the redactor reads the state fiels, identifies the sensitive data and replaces it.
The supported remote services:
| **Service**           | **Authentication**                                                | **Notes**                                                                                                                                  |
|-----------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| Terraform Cloud (tfc) | Use `IACATHON_TFC_TOKEN` in the `values.yaml` under `credentials` | If using terraform enterprise, add the `IACATHON_TFC_CUSTOM_DOMAIN` under `credentials` or add the `address` under `firefly.location.tfc`. |

The redaction is for the following terraform providers (`Sensitive` attributes):

:white_check_mark: [AWS](https://registry.terraform.io/providers/hashicorp/aws)

:white_check_mark: [Google Cloud](https://registry.terraform.io/providers/hashicorp/google)

:white_check_mark: [Kubernetes](https://registry.terraform.io/providers/hashicorp/google)

:white_check_mark: [Datadog](https://registry.terraform.io/providers/DataDog/datadog)

:white_check_mark: [New Relic](https://registry.terraform.io/providers/newrelic/newrelic)

:white_check_mark: [Akamai](https://registry.terraform.io/providers/akamai/akamai)

:white_check_mark: [Github](https://registry.terraform.io/providers/integrations/github)

**In any case**, the redactor uses [Gitleaks](https://github.com/zricethezav/gitleaks) on every resource in order to enhance and make sure no secrets being written to mirror S3 bucket.

The Cron Job runs every 2 hours by default. The Cron Job is designed to run on an EKS cluster since it relays on the `eks.amazonaws.com/role-arn` annotation. The role must have an OpenID trust relationship and must grant:
* s3:GetBucket - for target bucket
* s3:ListBucket - to list objects under the target bucket
* s3:GetObject - to get object (suffixes: `.tfstate`, `.jsonl`)
* s3:PutObject - to put new object (suffixes: `.tfstate`, `.jsonl`)
* (Optional) kms:Decrypt - if the bucket is encrypted.


An example values:
```yaml
serviceAccount:
  annotations: {
     "gofirefly.io/component": firefly-redactor,
     "eks.amazonaws.com/role-arn": aws:aws:iam::123456789:role/my-role
  }
firefly:
  accountId: ID-GIVEN-BY-FIREFLY
  crawlerId: ID-GIVEN-BY-FIREFLY
  location:
    tfc:
      organization: example
      address: example-tfc-enteprise.com
  type: tfc

credentials:
  IACATHON_TFC_TOKEN: MY-ORGANIZATION-TOKEN
  IACATHON_TFC_CUSTOM_DOMAIN: example-tfc-enteprise.com

redactorMirrorBucketName: my-mirror-bucket
redactorMirrorBucketRegion: us-east-1
```
