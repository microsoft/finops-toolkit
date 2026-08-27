// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// App metadata definition
//==============================================================================

@export()
@description('Metadata for resources created by the Invoices app.')
type AppMetadata = {
  @description('Fully-qualified app identifier.')
  id: string
  @description('App version.')
  version: string
  @description('Storage container and folder where invoice files are saved.')
  storage: {
    @description('Container where invoice files are saved.')
    container: string
    @description('Root folder within the container where invoice files are saved.')
    folder: string
  }
  @description('Data Factory dataset names.')
  datasets: {
    @description('Binary dataset for the invoice download URL.')
    invoiceDownload: string
    @description('Binary dataset for the invoice file saved in storage.')
    invoiceFile: string
  }
  @description('Data Factory linked service names.')
  linkedServices: {
    @description('HTTP linked service used to download invoice files.')
    invoiceDownload: string
  }
  @description('Data Factory pipeline names.')
  pipelines: {
    @description('Pipeline that downloads invoices for all configured billing accounts.')
    downloadInvoices: string
  }
}
