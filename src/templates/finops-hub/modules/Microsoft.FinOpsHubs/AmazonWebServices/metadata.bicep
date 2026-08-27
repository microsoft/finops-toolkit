// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// App metadata definition
//==============================================================================

@export()
@description('Metadata for resources created by the Amazon Web Services app.')
type AppMetadata = {
  @description('Fully-qualified app identifier.')
  id: string
  @description('App version.')
  version: string
  @description('Storage container and folder where collected FOCUS files are staged.')
  storage: {
    @description('Container where collected FOCUS files are staged for the ETL pipeline.')
    container: string
    @description('Root folder within the container where collected FOCUS files are staged.')
    folder: string
  }
  @description('Data Factory dataset names.')
  datasets: {
    @description('Binary dataset used to list the export manifest folder in Amazon S3.')
    focusManifestFolder: string
    @description('JSON dataset for the Amazon Web Services export manifest read from Amazon S3.')
    focusManifest: string
    @description('Binary dataset for FOCUS files read from Amazon S3.')
    focusSource: string
    @description('Binary dataset for FOCUS files staged in the export container.')
    focusLanding: string
    @description('Text dataset used to write the generated export manifest to the export container.')
    focusManifestLanding: string
  }
  @description('Data Factory linked service names.')
  linkedServices: {
    @description('Amazon S3 linked service used to read the FOCUS export.')
    amazonS3: string
  }
  @description('Data Factory pipeline names.')
  pipelines: {
    @description('Pipeline that collects FOCUS files for all configured billing periods.')
    collectFocusExport: string
    @description('Pipeline that resolves the export manifest for a single billing period.')
    collectFocusExportPeriod: string
    @description('Pipeline that stages the files listed in a single export manifest.')
    collectFocusExportManifest: string
  }
}
