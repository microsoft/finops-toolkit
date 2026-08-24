# Microsoft.FinOpsHubs/AmazonWebServices

Collects FOCUS cost data exported from Amazon Web Services into the FinOps hub so AWS costs are ingested, normalized, and reported alongside Microsoft Cloud costs.

The app only handles **collection**. Once the files are staged in the export container, the existing FinOps hub ETL converts, normalizes, and ingests them with no changes: the generated manifest points at the `focuscost_1.2-aws.json` schema, which the ingestion pipeline loads the same way it loads a Cost Management schema.

## What gets deployed

| Resource | Name | Description |
| -------- | ---- | ----------- |
| Key Vault secret | `aws-secret-access-key` | AWS secret access key. Never stored in the linked service definition. |
| Linked service | `aws_s3` | Amazon S3 connection using access key authentication. |
| Dataset | `aws_focus_manifest_folder` | Binary folder used to discover the export manifest. |
| Dataset | `aws_focus_manifest` | JSON export manifest read in place from Amazon S3. |
| Dataset | `aws_focus_source` | Binary FOCUS data file in Amazon S3. |
| Dataset | `aws_focus_landing` | Binary FOCUS data file staged in the export container. |
| Dataset | `aws_focus_manifest_landing` | Text sink used to write the generated manifest. |
| Pipeline | `aws_CollectFocusExport` | Entry point. Collects the current and previous billing periods. |
| Pipeline | `aws_CollectFocusExportPeriod` | Locates the export manifest for one billing period. |
| Pipeline | `aws_CollectFocusExportManifest` | Copies the files listed in one manifest and publishes the generated manifest. |
| Trigger | `aws_DailySchedule` | Runs once a day. |

Files are staged in the **msexports** container using the following hierarchy:

```text
msexports/
└── aws/
    └── {accountId}/
        └── {YYYY-MM}/
            └── {runId}/
                ├── {export-name}-00001.snappy.parquet
                └── manifest.json
```

After ingestion, the data lands in `ingestion/Costs/{YYYY}/{MM}/aws/{accountId}/`.

## Requirements

| # | Requirement | Notes |
| - | ----------- | ----- |
| 1 | A FOCUS 1.2 export in AWS Data Exports | Create it in **Billing and Cost Management** > **Data Exports**. Export type must be **FOCUS 1.2**. |
| 2 | An S3 bucket that receives the export | Parquet and gzipped CSV are both supported. |
| 3 | An IAM user with read access to the bucket | Needs `s3:GetObject` and `s3:ListBucket` on the bucket and its contents. |
| 4 | An access key ID and secret access key for that user | The secret is stored in the hub Key Vault during deployment. |
| 5 | The AWS account ID | Used to isolate the data in the hub data lake. |

## Configuration

Enable the feature with the **Multicloud** step in the deployment wizard, or set the following template parameters:

| Parameter | Description |
| --------- | ----------- |
| `enableAwsFocusIngestion` | Set to `true` to deploy the app. Default: `false`. |
| `awsBucketName` | Name of the S3 bucket that contains the export. |
| `awsBucketPath` | Path to the export root folder within the bucket. This is the folder that contains the `data` and `metadata` subfolders. Example: `reports/focus-export`. |
| `awsAccountId` | AWS account ID that owns the export. |
| `awsRegion` | Region of the bucket. Leave empty to use the global S3 endpoint. |
| `awsAccessKeyId` | Access key ID used to read the bucket. |
| `awsSecretAccessKey` | Secret access key used to read the bucket. |
| `awsFocusVersion` | FOCUS version of the export. Only `1.2` is supported. |
| `multiCloudScheduleHour` | Hour of the day (UTC) to collect files. Default: `4`. |

### Finding the bucket path

For an export delivered to `s3://my-bucket/reports/focus-export/data/billing_period=2026-05/`, set `awsBucketName` to `my-bucket` and `awsBucketPath` to `reports/focus-export`. Do not include leading or trailing slashes, and do not include `data` or `metadata`.

### Minimum IAM policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::my-bucket"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::my-bucket/reports/focus-export/*"
    }
  ]
}
```

## How collection works

1. The daily trigger runs `aws_CollectFocusExport`, which iterates the current and previous billing period. AWS may restate a closed period for up to two weeks, so the previous period is always re-collected.
2. For each period, `aws_CollectFocusExportPeriod` lists `{bucketPath}/metadata/billing_period={YYYY-MM}/` and looks for the export manifest. When the period has not been exported yet, the folder does not exist and the pipeline completes without doing anything.
3. `aws_CollectFocusExportManifest` reads the manifest, copies only the files listed in its `dataFiles` array, then writes a generated `manifest.json` in the same staging folder.
4. Writing that manifest fires the existing `msexports_ManifestAdded` trigger, which starts the normal ingestion pipeline.

Three details of this flow matter and should not be changed casually:

- **Only the files listed in `dataFiles` are copied.** When an export is configured to create a new file on every refresh, the `data/billing_period={YYYY-MM}/` folder accumulates one subfolder per day. Listing the folder recursively would copy every refresh and multiply the month's costs.
- **The AWS manifest is never copied into the export container.** Its schema is incompatible with the manifest contract the ETL expects. It is read in place and left in Amazon S3.
- **The generated manifest is written last**, and only after every copy has succeeded, so ingestion never starts on a partial set of files.

## Idempotency

Every run generates a new `runId`, which the ETL uses as the ingestion ID. Data Explorer replaces all data tagged with a previous ingestion ID for the same destination folder, so re-collecting a period replaces it rather than adding to it.

This depends on the destination path being stable and lowercase. The account ID is lowercased before it is used, because the Data Explorer `drop-by` tag is case-sensitive: ingesting the same data under `aws/123456789012` and `AWS/123456789012` produces two tags that coexist and silently double the reported cost.

## Validate the deployment

1. Open the hub Data Factory and run the `aws_CollectFocusExport` pipeline in debug mode.
2. Confirm each activity succeeds:
   - `Find Manifest` reports `exists: true` for the current period.
   - `Filter Manifest Files` returns exactly one item.
   - `Copy FOCUS Files` reports more than 0 bytes written for each file.
   - `Write Manifest` completes.
3. Confirm the staged files exist under `aws/{accountId}/{YYYY-MM}/` in the **msexports** container, and that `manifest.json` is valid JSON.
4. Confirm the `msexports_ExecuteETL` pipeline started on its own within a couple of minutes.
5. Query the ingestion table and confirm rows arrived with `x_SourceProvider` set for AWS.

## Troubleshooting

| Symptom | Cause | Resolution |
| ------- | ----- | ---------- |
| `Find Manifest` fails with an access error | The access key is wrong, expired, or the IAM user cannot list the bucket. | Confirm the key in Key Vault and the IAM policy above. |
| `Find Manifest` reports `exists: false` every run | `awsBucketPath` is wrong, or the export has not run yet. | Confirm the path contains the `data` and `metadata` folders. Do not include `data` or `metadata` in the value. |
| `Filter Manifest Files` returns 0 items | The metadata partition exists but holds no manifest. | Confirm the export completed in AWS for that period. |
| `Copy FOCUS Files` fails with a not found error | The object key was built incorrectly. | Confirm `awsBucketName` matches the bucket in the `s3://` URIs in the manifest. A mismatch leaves the prefix in the key. |
| `msexports_ExecuteETL` never starts | The generated manifest is not valid JSON, or it was not written to the export container. | Download `manifest.json` from the staging folder and validate it. |
| Ingestion runs but no rows appear | The generated manifest reported no files. | Confirm `blobCount` is greater than zero and that `dataRowCount` is absent. A `dataRowCount` of `0` makes the ETL treat the export as empty. |
| Costs are doubled | The same period was ingested under two different paths. | Confirm `awsAccountId` is lowercase and has not changed between runs. |
| Ingestion fails on a column mapping | The export schema drifted, or the export is not FOCUS 1.2. | Compare the manifest's `columns` array against `focuscost_1.2-aws.json`. |

## Cost

Data Factory activity runs, the data movement itself, and staging storage are added. Cross-cloud egress is billed by AWS, not Azure. For a single account with a few hundred megabytes of FOCUS data a month, expect a few USD per month on the Azure side.
