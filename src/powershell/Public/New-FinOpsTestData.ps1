# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#Requires -Version 7.0

<#
    .SYNOPSIS
    Generates multi-cloud FOCUS-compliant test data for FinOps Hub validation.

    .DESCRIPTION
    This script generates synthetic cost data in FOCUS format for:
    - Azure (Cost Management Managed Exports simulation)
    - AWS (Data Exports / CUR FOCUS format)
    - GCP (BigQuery FOCUS export simulation)
    - Data Center (On-premises infrastructure)

    In addition, for Azure, it generates ALL FOCUS dataset types:
    - Prices (Azure EA/MCA price sheet → Prices_raw → Prices_final_v1_2)
    - CommitmentDiscountUsage (Reservation details → CommitmentDiscountUsage_raw)
    - Recommendations (Reservation recommendations → Recommendations_raw)
    - Transactions (Reservation transactions → Transactions_raw)

    The generated data can be uploaded to Azure Storage for FinOps Hub ingestion testing.

    Features:
    - Version-aware column sets matching FOCUS 1.0, 1.1, 1.2, or 1.3 specification
    - ALL columns referenced by FinOps Hub dashboard KQL queries
    - Correct PricingCategory values: Standard, Dynamic, Committed
    - Full Azure Hybrid Benefit simulation with x_SkuLicense* columns
    - Commitment discounts with x_SkuOrderId, x_SkuTerm linkage
    - Commitment Purchase rows for invoicing page
    - CPU architecture in x_SkuMeterName (Intel/AMD/Arm64 patterns)
    - Tag coverage variation (~20% untagged for maturity scorecard)
    - Data quality anomaly rows (documented via x_SourceChanges, ChargeClass=Correction)
    - Negotiated discount rows (ListCost > ContractedCost)
    - Persistent resources across days (realistic trending)
    - Inline budget scaling (no external dependencies)
    - Reproducible output via -Seed parameter

    .PARAMETER OutputPath
    Directory to save generated files. Default: ./test-data

    .PARAMETER ServiceProvider
    Which cloud provider data to generate. Options: Azure, AWS, GCP, DataCenter, All
    Default: All

    .PARAMETER MonthsOfData
    Number of months of historical data to generate, ending at today.
    Default: 6 (generates 6 months ending today)

    .PARAMETER StartDate
    Start date for generated data. Overrides MonthsOfData if specified.

    .PARAMETER EndDate
    End date for generated data. Default: Today

    .PARAMETER RowCount
    Target total rows across all providers and days. Default: 500000
    Rows are distributed: ~60% Azure, ~20% AWS, ~15% GCP, ~5% DataCenter

    .PARAMETER TotalCost
    Target total cost in USD for all generated data. Default: 500000 ($500K)
    Costs are scaled proportionally during generation to achieve this target.

    .PARAMETER FocusVersion
    FOCUS specification version. Options: 1.0, 1.1, 1.2, 1.3
    Default: 1.3
    The output column set varies per version to match the official FOCUS specification.
    Note: This generates the Cost and Usage dataset only. The Contract Commitment
    dataset (introduced in v1.3) is not included.

    .PARAMETER OutputFormat
    Output file format. Options: CSV, Parquet
    Default: Parquet
    Parquet is recommended as it simulates real Cost Management export output.
    Data is generated via per-day CSV streaming (to avoid OOM), then converted
    to Parquet at the end. Requires the PSParquet module (Install-Module PSParquet).
    CSV mode skips the final conversion and uploads raw CSV files.

    .PARAMETER StorageAccountName
    Azure Storage account name. When specified, generated files are uploaded to
    Azure Storage using Azure AD authentication after generation completes.

    .PARAMETER ResourceGroupName
    Resource group containing the storage account and ADF instance.
    Required when using -StartTriggers to ensure ADF triggers are running.

    .PARAMETER AdfName
    Azure Data Factory name. Required when using -StartTriggers to start/verify
    ADF triggers before uploading data.

    .PARAMETER StartTriggers
    Start ADF triggers before upload so BlobCreated events are captured.
    Triggers must be running for Event Grid to fire ADF pipelines. If triggers
    were stopped (e.g., during cleanup), use this switch to restart them.

    .PARAMETER Seed
    Random seed for reproducible test data generation. When specified, the same seed
    produces identical output (given the same parameters).

    .EXAMPLE
    New-FinOpsTestData
    # Generates 6 months of FOCUS 1.3 data for all providers, 500K rows, $500K budget

    .EXAMPLE
    New-FinOpsTestData -MonthsOfData 3 -RowCount 100000 -TotalCost 50000
    # Generates 3 months of data, 100K rows, $50K total budget

    .EXAMPLE
    New-FinOpsTestData -FocusVersion 1.0 -ServiceProvider Azure -RowCount 50000
    # Generates FOCUS 1.0 Azure-only data with 43 columns

    .EXAMPLE
    New-FinOpsTestData -StorageAccountName "stfinopshub" -ResourceGroupName "rg-finopshub" -AdfName "adf-finopshub" -StartTriggers
    # Generates data, ensures ADF triggers are running, then uploads to Azure Storage

    .EXAMPLE
    New-FinOpsTestData -Seed 42 -RowCount 1000
    # Generates reproducible test data with 1000 rows

    .LINK
    https://aka.ms/ftk/New-FinOpsTestData

    .NOTES
    FOCUS Specification Reference: https://focus.finops.org/focus-specification/v1-3/
    FinOps Hub Documentation: https://aka.ms/finops/hubs

    Author: FinOps Hub Team
    Version: 4.0.0
#>

function New-FinOpsTestData
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colored interactive output is intentional for progress reporting and summary display')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$OutputPath = "./test-data",

        [ValidateSet("Azure", "AWS", "GCP", "DataCenter", "All")]
        [string]$ServiceProvider = "All",

        [int]$MonthsOfData = 6,

        [datetime]$StartDate,

        [datetime]$EndDate = (Get-Date),

        [int]$RowCount = 500000,

        [decimal]$TotalCost = 500000,

        [ValidateSet("1.0", "1.1", "1.2", "1.3")]
        [string]$FocusVersion = "1.3",

        [ValidateSet("CSV", "Parquet")]
        [string]$OutputFormat = "Parquet",

        [string]$StorageAccountName,

        [string]$ResourceGroupName,

        [string]$AdfName,

        [switch]$StartTriggers,

        [int]$Seed
    )

    # ============================================================================
    # Initialization
    # ============================================================================

    # Set random seed for reproducibility if specified
    if ($PSBoundParameters.ContainsKey('Seed'))
    {
        $null = Get-Random -SetSeed $Seed
    }

    # Calculate StartDate from MonthsOfData if not explicitly provided
    if (-not $PSBoundParameters.ContainsKey('StartDate'))
    {
        $StartDate = (Get-Date -Day 1).AddMonths(-$MonthsOfData + 1)
    }

    # Ensure EndDate is today max
    if ($EndDate -gt (Get-Date))
    {
        $EndDate = Get-Date
    }

    # Verify PSParquet module is available when Parquet output is requested
    if ($OutputFormat -eq 'Parquet')
    {
        if (-not (Get-Module -ListAvailable -Name PSParquet))
        {
            throw "The PSParquet module is required for Parquet output. Install it with: Install-Module PSParquet -Scope CurrentUser"
        }
    }

    # Parse FOCUS version for column selection
    $focusMajorMinor = [version]$FocusVersion

    # ADF trigger names used during upload operations.
    # These match the default FinOps Hub ADF trigger names. Override if your deployment
    # uses custom trigger names.
    $AdfTriggerNames = @('msexports_ManifestAdded', 'ingestion_ManifestAdded')

    # ============================================================================
    # Provider-Specific Configuration
    # ============================================================================

    # ServiceSubcategory values aligned to FOCUS specification closed enumeration.
    # Reference: https://focus.finops.org/focus-specification/ (ServiceSubcategory column)
    $ProviderConfigs = @{
        Azure      = @{
            ProviderName            = "Microsoft"
            ServiceProviderName     = "Microsoft"
            InvoiceIssuerName       = "Microsoft"
            HostProviderName        = "Microsoft"
            BillingAccountType      = "Billing Account"
            SubAccountType          = "Subscription"
            BillingCurrency         = "USD"
            BillingAccountAgreement = "Enterprise Agreement"
            Regions                 = @(
                @{ Id = "swedencentral"; Name = "Sweden Central" },
                @{ Id = "westeurope"; Name = "West Europe" },
                @{ Id = "eastus"; Name = "East US" },
                @{ Id = "westus2"; Name = "West US 2" },
                @{ Id = "italynorth"; Name = "Italy North" }
            )
            Services                = @(
                @{ Name = "Virtual Machines"; Category = "Compute"; Subcategory = "Virtual Machines"; Weight = 35; CostMin = 50; CostMax = 2000; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Azure Kubernetes Service"; Category = "Compute"; Subcategory = "Containers"; Weight = 20; CostMin = 100; CostMax = 3000; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Azure SQL Database"; Category = "Databases"; Subcategory = "Relational Databases"; Weight = 12; CostMin = 30; CostMax = 800; PricingUnit = "1 Hour"; ConsumedUnit = "DTUs"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Cosmos DB"; Category = "Databases"; Subcategory = "NoSQL"; Weight = 8; CostMin = 20; CostMax = 500; PricingUnit = "100 RUs"; ConsumedUnit = "Request Units"; PricingBlockSize = 100; PricingUnitDescription = "100 Request Units" },
                @{ Name = "Storage Accounts"; Category = "Storage"; Subcategory = "Object Storage"; Weight = 10; CostMin = 5; CostMax = 200; PricingUnit = "1 GB"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB/Month" },
                @{ Name = "Azure Data Explorer"; Category = "Analytics"; Subcategory = "Other (Analytics)"; Weight = 5; CostMin = 50; CostMax = 600; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "App Service"; Category = "Compute"; Subcategory = "Other (Compute)"; Weight = 4; CostMin = 10; CostMax = 300; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Key Vault"; Category = "Security"; Subcategory = "Other (Security)"; Weight = 2; CostMin = 1; CostMax = 50; PricingUnit = "10K Operations"; ConsumedUnit = "10K Operations"; PricingBlockSize = 10000; PricingUnitDescription = "10,000 Operations" },
                @{ Name = "Virtual Network"; Category = "Networking"; Subcategory = "Network Infrastructure"; Weight = 2; CostMin = 5; CostMax = 100; PricingUnit = "1 GB"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB" },
                @{ Name = "Managed Disks"; Category = "Storage"; Subcategory = "Disk Storage"; Weight = 6; CostMin = 5; CostMax = 150; PricingUnit = "1 GB/Month"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB/Month" },
                @{ Name = "Public IP Addresses"; Category = "Networking"; Subcategory = "IP Addresses"; Weight = 3; CostMin = 3; CostMax = 30; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Load Balancer"; Category = "Networking"; Subcategory = "Load Balancing"; Weight = 3; CostMin = 18; CostMax = 100; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Azure Functions"; Category = "Compute"; Subcategory = "Functions"; Weight = 2; CostMin = 0.10; CostMax = 30; PricingUnit = "1M Executions"; ConsumedUnit = "1M Executions"; PricingBlockSize = 1000000; PricingUnitDescription = "1,000,000 Executions" },
                @{ Name = "Azure Marketplace"; Category = "Marketplace"; Subcategory = "Other (Compute)"; Weight = 5; CostMin = 10; CostMax = 500; PricingUnit = "1 Hour"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour"; IsMarketplace = $true }
            )
            ResourceTypes           = @("microsoft.compute/virtualmachines", "microsoft.compute/disks", "microsoft.storage/storageaccounts", "microsoft.sql/servers", "microsoft.kusto/clusters", "microsoft.containerservice/managedclusters", "microsoft.documentdb/databaseaccounts", "microsoft.web/sites", "microsoft.keyvault/vaults", "microsoft.network/virtualnetworks", "microsoft.network/publicipaddresses", "microsoft.network/loadbalancers")
            VmSkus                  = @(
                @{ InstanceType = "Standard_D4s_v5"; Cores = 4; Arch = "Intel"; MeterName = "D4s v5"; Description = "D4s v5 (4 vCPUs, 16 GB RAM)" },
                @{ InstanceType = "Standard_D8s_v5"; Cores = 8; Arch = "Intel"; MeterName = "D8s v5"; Description = "D8s v5 (8 vCPUs, 32 GB RAM)" },
                @{ InstanceType = "Standard_D16s_v5"; Cores = 16; Arch = "Intel"; MeterName = "D16s v5"; Description = "D16s v5 (16 vCPUs, 64 GB RAM)" },
                @{ InstanceType = "Standard_E4s_v5"; Cores = 4; Arch = "Intel"; MeterName = "E4s v5"; Description = "E4s v5 (4 vCPUs, 32 GB RAM)" },
                @{ InstanceType = "Standard_E16s_v5"; Cores = 16; Arch = "Intel"; MeterName = "E16s v5"; Description = "E16s v5 (16 vCPUs, 128 GB RAM)" },
                @{ InstanceType = "Standard_D4as_v5"; Cores = 4; Arch = "AMD"; MeterName = "D4as v5"; Description = "D4as v5 AMD (4 vCPUs, 16 GB RAM)" },
                @{ InstanceType = "Standard_D8as_v5"; Cores = 8; Arch = "AMD"; MeterName = "D8as v5"; Description = "D8as v5 AMD (8 vCPUs, 32 GB RAM)" },
                @{ InstanceType = "Standard_E8as_v5"; Cores = 8; Arch = "AMD"; MeterName = "E8as v5"; Description = "E8as v5 AMD (8 vCPUs, 64 GB RAM)" },
                @{ InstanceType = "Standard_D4ps_v5"; Cores = 4; Arch = "Arm64"; MeterName = "D4ps v5"; Description = "D4ps v5 Arm64 (4 vCPUs, 16 GB RAM)" },
                @{ InstanceType = "Standard_D8ps_v5"; Cores = 8; Arch = "Arm64"; MeterName = "D8ps v5"; Description = "D8ps v5 Arm64 (8 vCPUs, 32 GB RAM)" },
                @{ InstanceType = "Standard_E4ps_v5"; Cores = 4; Arch = "Arm64"; MeterName = "E4ps v5"; Description = "E4ps v5 Arm64 (4 vCPUs, 32 GB RAM)" },
                @{ InstanceType = "Standard_B2s"; Cores = 2; Arch = "Intel"; MeterName = "B2s"; Description = "B2s Burstable (2 vCPUs, 4 GB RAM)" },
                @{ InstanceType = "Standard_F4s_v2"; Cores = 4; Arch = "Intel"; MeterName = "F4s v2"; Description = "F4s v2 Compute (4 vCPUs, 8 GB RAM)" },
                # GPU N-series VMs (NC = training/inference, ND = distributed training, NV = visualization, NG = gaming/VDI)
                @{ InstanceType = "Standard_NC4as_T4_v3"; Cores = 4; Arch = "GPU"; GpuType = "T4"; GpuCount = 1; MeterName = "NC4as T4 v3"; Description = "NC4as T4 v3 GPU (4 vCPUs, 28 GB, 1x T4)" },
                @{ InstanceType = "Standard_NC24ads_A100_v4"; Cores = 24; Arch = "GPU"; GpuType = "A100"; GpuCount = 1; MeterName = "NC24ads A100 v4"; Description = "NC24ads A100 v4 GPU (24 vCPUs, 220 GB, 1x A100)" },
                @{ InstanceType = "Standard_NC40ads_H100_v5"; Cores = 40; Arch = "GPU"; GpuType = "H100"; GpuCount = 1; MeterName = "NC40ads H100 v5"; Description = "NC40ads H100 v5 GPU (40 vCPUs, 320 GB, 1x H100)" },
                @{ InstanceType = "Standard_ND96asr_v4"; Cores = 96; Arch = "GPU"; GpuType = "A100"; GpuCount = 8; MeterName = "ND96asr v4"; Description = "ND96asr v4 GPU (96 vCPUs, 900 GB, 8x A100)" },
                @{ InstanceType = "Standard_ND96isr_H100_v5"; Cores = 96; Arch = "GPU"; GpuType = "H100"; GpuCount = 8; MeterName = "ND96isr H100 v5"; Description = "ND96isr H100 v5 GPU (96 vCPUs, 1900 GB, 8x H100)" },
                @{ InstanceType = "Standard_ND96isr_MI300X_v5"; Cores = 96; Arch = "GPU"; GpuType = "MI300X"; GpuCount = 8; MeterName = "ND96isr MI300X v5"; Description = "ND96isr MI300X v5 GPU (96 vCPUs, 1700 GB, 8x MI300X)" },
                @{ InstanceType = "Standard_NV36ads_A10_v5"; Cores = 36; Arch = "GPU"; GpuType = "A10"; GpuCount = 1; MeterName = "NV36ads A10 v5"; Description = "NV36ads A10 v5 GPU (36 vCPUs, 440 GB, 1x A10)" },
                @{ InstanceType = "Standard_NV36adms_A10_v5"; Cores = 36; Arch = "GPU"; GpuType = "A10"; GpuCount = 1; MeterName = "NV36adms A10 v5"; Description = "NV36adms A10 v5 GPU (36 vCPUs, 880 GB, 1x A10)" },
                @{ InstanceType = "Standard_NG8ads_V620_v1"; Cores = 8; Arch = "GPU"; GpuType = "V620"; GpuCount = 1; MeterName = "NG8ads V620 v1"; Description = "NG8ads V620 v1 GPU (8 vCPUs, 16 GB, 1/2 V620)" }
            )
        }
        AWS        = @{
            ProviderName            = "Amazon Web Services"
            ServiceProviderName     = "Amazon Web Services"
            InvoiceIssuerName       = "Amazon Web Services"
            HostProviderName        = "Amazon Web Services"
            BillingAccountType      = "Management Account"
            SubAccountType          = "Member Account"
            BillingCurrency         = "USD"
            BillingAccountAgreement = "AWS Customer Agreement"
            Regions                 = @(
                @{ Id = "us-east-1"; Name = "US East (N. Virginia)" },
                @{ Id = "us-west-2"; Name = "US West (Oregon)" },
                @{ Id = "eu-west-1"; Name = "Europe (Ireland)" },
                @{ Id = "ap-southeast-1"; Name = "Asia Pacific (Singapore)" }
            )
            Services                = @(
                @{ Name = "Amazon EC2"; Category = "Compute"; Subcategory = "Virtual Machines"; Weight = 35; CostMin = 50; CostMax = 2000; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Amazon EKS"; Category = "Compute"; Subcategory = "Containers"; Weight = 18; CostMin = 100; CostMax = 2500; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Amazon RDS"; Category = "Databases"; Subcategory = "Relational Databases"; Weight = 12; CostMin = 30; CostMax = 800; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Amazon S3"; Category = "Storage"; Subcategory = "Object Storage"; Weight = 12; CostMin = 5; CostMax = 300; PricingUnit = "GB"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB" },
                @{ Name = "Amazon Redshift"; Category = "Analytics"; Subcategory = "Data Warehouses"; Weight = 8; CostMin = 50; CostMax = 1000; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Amazon DynamoDB"; Category = "Databases"; Subcategory = "NoSQL"; Weight = 6; CostMin = 10; CostMax = 400; PricingUnit = "RCUs"; ConsumedUnit = "Read Capacity Units"; PricingBlockSize = 1; PricingUnitDescription = "1 Read Capacity Unit" },
                @{ Name = "Amazon CloudFront"; Category = "Networking"; Subcategory = "Content Delivery"; Weight = 4; CostMin = 5; CostMax = 150; PricingUnit = "GB"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB" },
                @{ Name = "AWS Lambda"; Category = "Compute"; Subcategory = "Functions"; Weight = 3; CostMin = 0.10; CostMax = 30; PricingUnit = "Requests"; ConsumedUnit = "1M Requests"; PricingBlockSize = 1000000; PricingUnitDescription = "1,000,000 Requests" },
                @{ Name = "Amazon SQS"; Category = "Integration"; Subcategory = "Other (Integration)"; Weight = 2; CostMin = 0.50; CostMax = 20; PricingUnit = "Requests"; ConsumedUnit = "1M Requests"; PricingBlockSize = 1000000; PricingUnitDescription = "1,000,000 Requests" }
            )
            ResourceTypes           = @("AWS::EC2::Instance", "AWS::S3::Bucket", "AWS::RDS::DBInstance", "AWS::EKS::Cluster", "AWS::DynamoDB::Table", "AWS::Lambda::Function")
            VmSkus                  = @(
                # CPU instance types
                @{ InstanceType = "m5.xlarge"; Cores = 4; Arch = "Intel"; MeterName = "m5.xlarge"; Description = "m5.xlarge (4 vCPUs, 16 GB)" },
                @{ InstanceType = "m5.2xlarge"; Cores = 8; Arch = "Intel"; MeterName = "m5.2xlarge"; Description = "m5.2xlarge (8 vCPUs, 32 GB)" },
                @{ InstanceType = "m6a.xlarge"; Cores = 4; Arch = "AMD"; MeterName = "m6a.xlarge"; Description = "m6a.xlarge AMD (4 vCPUs, 16 GB)" },
                @{ InstanceType = "m6a.2xlarge"; Cores = 8; Arch = "AMD"; MeterName = "m6a.2xlarge"; Description = "m6a.2xlarge AMD (8 vCPUs, 32 GB)" },
                @{ InstanceType = "m6g.xlarge"; Cores = 4; Arch = "Arm64"; MeterName = "m6g.xlarge"; Description = "m6g.xlarge Graviton (4 vCPUs, 16 GB)" },
                @{ InstanceType = "m6g.2xlarge"; Cores = 8; Arch = "Arm64"; MeterName = "m6g.2xlarge"; Description = "m6g.2xlarge Graviton (8 vCPUs, 32 GB)" },
                @{ InstanceType = "c5.2xlarge"; Cores = 8; Arch = "Intel"; MeterName = "c5.2xlarge"; Description = "c5.2xlarge Compute (8 vCPUs, 16 GB)" },
                @{ InstanceType = "r5.xlarge"; Cores = 4; Arch = "Intel"; MeterName = "r5.xlarge"; Description = "r5.xlarge Memory (4 vCPUs, 32 GB)" },
                # GPU instance types
                @{ InstanceType = "p4d.24xlarge"; Cores = 96; Arch = "GPU"; GpuType = "A100"; GpuCount = 8; MeterName = "p4d.24xlarge"; Description = "p4d.24xlarge GPU (96 vCPUs, 1152 GB, 8x A100)" },
                @{ InstanceType = "p5.48xlarge"; Cores = 192; Arch = "GPU"; GpuType = "H100"; GpuCount = 8; MeterName = "p5.48xlarge"; Description = "p5.48xlarge GPU (192 vCPUs, 2048 GB, 8x H100)" },
                @{ InstanceType = "g5.xlarge"; Cores = 4; Arch = "GPU"; GpuType = "A10G"; GpuCount = 1; MeterName = "g5.xlarge"; Description = "g5.xlarge GPU (4 vCPUs, 16 GB, 1x A10G)" },
                @{ InstanceType = "g5.2xlarge"; Cores = 8; Arch = "GPU"; GpuType = "A10G"; GpuCount = 1; MeterName = "g5.2xlarge"; Description = "g5.2xlarge GPU (8 vCPUs, 32 GB, 1x A10G)" },
                @{ InstanceType = "g4dn.xlarge"; Cores = 4; Arch = "GPU"; GpuType = "T4"; GpuCount = 1; MeterName = "g4dn.xlarge"; Description = "g4dn.xlarge GPU (4 vCPUs, 16 GB, 1x T4)" },
                @{ InstanceType = "inf2.xlarge"; Cores = 4; Arch = "GPU"; GpuType = "Inferentia2"; GpuCount = 1; MeterName = "inf2.xlarge"; Description = "inf2.xlarge Inferentia (4 vCPUs, 32 GB, 1x Inf2)" },
                @{ InstanceType = "trn1.2xlarge"; Cores = 8; Arch = "GPU"; GpuType = "Trainium"; GpuCount = 1; MeterName = "trn1.2xlarge"; Description = "trn1.2xlarge Trainium (8 vCPUs, 32 GB, 1x Trn1)" }
            )
        }
        GCP        = @{
            ProviderName            = "Google Cloud"
            ServiceProviderName     = "Google Cloud"
            InvoiceIssuerName       = "Google Cloud"
            HostProviderName        = "Google Cloud"
            BillingAccountType      = "Billing Account"
            SubAccountType          = "Project"
            BillingCurrency         = "USD"
            BillingAccountAgreement = "Google Cloud Agreement"
            Regions                 = @(
                @{ Id = "us-central1"; Name = "Iowa" },
                @{ Id = "us-east1"; Name = "South Carolina" },
                @{ Id = "europe-west1"; Name = "Belgium" },
                @{ Id = "asia-east1"; Name = "Taiwan" }
            )
            Services                = @(
                @{ Name = "Compute Engine"; Category = "Compute"; Subcategory = "Virtual Machines"; Weight = 35; CostMin = 50; CostMax = 2000; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Google Kubernetes Engine"; Category = "Compute"; Subcategory = "Containers"; Weight = 20; CostMin = 100; CostMax = 2500; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Cloud SQL"; Category = "Databases"; Subcategory = "Relational Databases"; Weight = 12; CostMin = 30; CostMax = 700; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Cloud Storage"; Category = "Storage"; Subcategory = "Object Storage"; Weight = 12; CostMin = 5; CostMax = 250; PricingUnit = "GB"; ConsumedUnit = "GB"; PricingBlockSize = 1; PricingUnitDescription = "1 GB" },
                @{ Name = "BigQuery"; Category = "Analytics"; Subcategory = "Data Warehouses"; Weight = 10; CostMin = 20; CostMax = 800; PricingUnit = "TB Scanned"; ConsumedUnit = "TB"; PricingBlockSize = 1; PricingUnitDescription = "1 TB Scanned" },
                @{ Name = "Cloud Spanner"; Category = "Databases"; Subcategory = "Other (Databases)"; Weight = 5; CostMin = 50; CostMax = 500; PricingUnit = "Node-Hours"; ConsumedUnit = "Node Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Node-Hour" },
                @{ Name = "Cloud Run"; Category = "Compute"; Subcategory = "Containers"; Weight = 3; CostMin = 5; CostMax = 100; PricingUnit = "vCPU-Seconds"; ConsumedUnit = "vCPU Seconds"; PricingBlockSize = 1; PricingUnitDescription = "1 vCPU-Second" },
                @{ Name = "Cloud Functions"; Category = "Compute"; Subcategory = "Functions"; Weight = 3; CostMin = 0.10; CostMax = 30; PricingUnit = "Invocations"; ConsumedUnit = "1M Invocations"; PricingBlockSize = 1000000; PricingUnitDescription = "1,000,000 Invocations" }
            )
            ResourceTypes           = @("compute.googleapis.com/Instance", "storage.googleapis.com/Bucket", "sql.googleapis.com/Instance", "container.googleapis.com/Cluster", "bigquery.googleapis.com/Dataset")
            VmSkus                  = @(
                # CPU instance types
                @{ InstanceType = "n2-standard-4"; Cores = 4; Arch = "Intel"; MeterName = "n2-standard-4"; Description = "n2-standard-4 (4 vCPUs, 16 GB)" },
                @{ InstanceType = "n2-standard-8"; Cores = 8; Arch = "Intel"; MeterName = "n2-standard-8"; Description = "n2-standard-8 (8 vCPUs, 32 GB)" },
                @{ InstanceType = "n2d-standard-4"; Cores = 4; Arch = "AMD"; MeterName = "n2d-standard-4"; Description = "n2d-standard-4 AMD (4 vCPUs, 16 GB)" },
                @{ InstanceType = "n2d-standard-8"; Cores = 8; Arch = "AMD"; MeterName = "n2d-standard-8"; Description = "n2d-standard-8 AMD (8 vCPUs, 32 GB)" },
                @{ InstanceType = "t2a-standard-4"; Cores = 4; Arch = "Arm64"; MeterName = "t2a-standard-4"; Description = "t2a-standard-4 Arm (4 vCPUs, 16 GB)" },
                @{ InstanceType = "c2-standard-8"; Cores = 8; Arch = "Intel"; MeterName = "c2-standard-8"; Description = "c2-standard-8 Compute (8 vCPUs, 32 GB)" },
                @{ InstanceType = "e2-standard-4"; Cores = 4; Arch = "Intel"; MeterName = "e2-standard-4"; Description = "e2-standard-4 (4 vCPUs, 16 GB)" },
                # GPU instance types
                @{ InstanceType = "a2-highgpu-1g"; Cores = 12; Arch = "GPU"; GpuType = "A100"; GpuCount = 1; MeterName = "a2-highgpu-1g"; Description = "a2-highgpu-1g GPU (12 vCPUs, 85 GB, 1x A100)" },
                @{ InstanceType = "a2-ultragpu-8g"; Cores = 96; Arch = "GPU"; GpuType = "A100"; GpuCount = 8; MeterName = "a2-ultragpu-8g"; Description = "a2-ultragpu-8g GPU (96 vCPUs, 1360 GB, 8x A100 80GB)" },
                @{ InstanceType = "a3-highgpu-8g"; Cores = 208; Arch = "GPU"; GpuType = "H100"; GpuCount = 8; MeterName = "a3-highgpu-8g"; Description = "a3-highgpu-8g GPU (208 vCPUs, 1872 GB, 8x H100)" },
                @{ InstanceType = "g2-standard-4"; Cores = 4; Arch = "GPU"; GpuType = "L4"; GpuCount = 1; MeterName = "g2-standard-4"; Description = "g2-standard-4 GPU (4 vCPUs, 16 GB, 1x L4)" },
                @{ InstanceType = "g2-standard-8"; Cores = 8; Arch = "GPU"; GpuType = "L4"; GpuCount = 1; MeterName = "g2-standard-8"; Description = "g2-standard-8 GPU (8 vCPUs, 32 GB, 1x L4)" },
                @{ InstanceType = "n1-standard-4-t4"; Cores = 4; Arch = "GPU"; GpuType = "T4"; GpuCount = 1; MeterName = "n1-standard-4+T4"; Description = "n1-standard-4+T4 GPU (4 vCPUs, 15 GB, 1x T4)" }
            )
        }
        DataCenter = @{
            ProviderName            = "Internal IT"
            ServiceProviderName     = "Internal IT"
            InvoiceIssuerName       = "Internal IT"
            HostProviderName        = "On-Premises"
            BillingAccountType      = "Cost Center"
            SubAccountType          = "Business Unit"
            BillingCurrency         = "USD"
            BillingAccountAgreement = "Internal SLA"
            Regions                 = @(
                @{ Id = "dc-us-east"; Name = "US East Data Center" },
                @{ Id = "dc-eu-west"; Name = "EU West Data Center" },
                @{ Id = "dc-apac"; Name = "APAC Data Center" }
            )
            Services                = @(
                @{ Name = "Physical Servers"; Category = "Compute"; Subcategory = "Other (Compute)"; Weight = 30; CostMin = 200; CostMax = 5000; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "VMware vSphere"; Category = "Compute"; Subcategory = "Virtual Machines"; Weight = 25; CostMin = 100; CostMax = 2000; PricingUnit = "Hours"; ConsumedUnit = "Hours"; PricingBlockSize = 1; PricingUnitDescription = "1 Hour" },
                @{ Name = "Oracle Database"; Category = "Databases"; Subcategory = "Relational Databases"; Weight = 15; CostMin = 500; CostMax = 5000; PricingUnit = "Processor Licenses"; ConsumedUnit = "Processor Licenses"; PricingBlockSize = 1; PricingUnitDescription = "1 Processor License" },
                @{ Name = "SAN Storage"; Category = "Storage"; Subcategory = "Block Storage"; Weight = 12; CostMin = 50; CostMax = 1500; PricingUnit = "TB"; ConsumedUnit = "TB"; PricingBlockSize = 1; PricingUnitDescription = "1 TB" },
                @{ Name = "Network Infrastructure"; Category = "Networking"; Subcategory = "Network Infrastructure"; Weight = 10; CostMin = 20; CostMax = 500; PricingUnit = "Ports"; ConsumedUnit = "Ports"; PricingBlockSize = 1; PricingUnitDescription = "1 Port" },
                @{ Name = "Facility Costs"; Category = "Other"; Subcategory = "Other"; Weight = 8; CostMin = 100; CostMax = 800; PricingUnit = "kWh"; ConsumedUnit = "kWh"; PricingBlockSize = 1; PricingUnitDescription = "1 kWh" }
            )
            ResourceTypes           = @("server/physical", "storage/san", "database/oracle", "virtualization/vmware")
        }
    }

    # ============================================================================
    # Helper Functions
    # ============================================================================

    function Get-RandomDecimal
    {
        param(
            [decimal]$Min = 0.01,
            [decimal]$Max = 100.00
        )
        # Use [long] to avoid [int] overflow with large ranges
        $range = [long](($Max - $Min) * 100 + 1)
        if ($range -le 0) { $range = 1 }
        # Get-Random -Maximum accepts [long] when > [int]::MaxValue
        $randomOffset = if ($range -gt [int]::MaxValue)
        {
            Get-Random -Minimum 0 -Maximum ([int]($range / 2)) + Get-Random -Minimum 0 -Maximum ([int]($range - $range / 2))
        }
        else
        {
            Get-Random -Maximum ([int]$range)
        }
        return [math]::Round($Min + $randomOffset / 100, 2)
    }

    function Get-RandomElement
    {
        param([array]$Array)
        return $Array[(Get-Random -Maximum $Array.Count)]
    }

    function Get-WeightedRandomService
    {
        param([array]$Services)

        $totalWeight = ($Services | ForEach-Object {
                if ($_.Weight) { $_.Weight } else { 1 }
            } | Measure-Object -Sum).Sum

        $randomValue = Get-Random -Maximum $totalWeight
        $cumulative = 0
        foreach ($service in $Services)
        {
            $weight = if ($service.Weight) { $service.Weight } else { 1 }
            $cumulative += $weight
            if ($randomValue -lt $cumulative)
            {
                return $service
            }
        }
        return $Services[-1]
    }

    function Get-IsoDateTime
    {
        param([datetime]$Date)
        return $Date.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    # Generate a 12-digit AWS-style account ID without int overflow
    function New-AwsAccountId
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param()
        # Split into two 6-digit segments to avoid [int] overflow
        # (12-digit numbers exceed [int]::MaxValue ~2.1B)
        $part1 = Get-Random -Minimum 100000 -Maximum 999999
        $part2 = Get-Random -Minimum 100000 -Maximum 999999
        return "$part1$part2"
    }

    # ============================================================================
    # Persistent Identity Generation
    # ============================================================================

    function New-ProviderIdentity
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [string]$Provider,
            [hashtable]$Config
        )

        # 2-3 Billing Accounts per provider
        $billingAccountCount = Get-Random -Minimum 2 -Maximum 4
        $billingAccounts = @()
        for ($i = 1; $i -le $billingAccountCount; $i++)
        {
            $baId = switch ($Provider)
            {
                "Azure" { [guid]::NewGuid().ToString() }
                "AWS" { New-AwsAccountId }
                "GCP" { "ABCDEF-$((Get-Random -Minimum 100000 -Maximum 999999))-$((Get-Random -Minimum 100000 -Maximum 999999))" }
                "DataCenter" { "CC-$(Get-Random -Minimum 10000 -Maximum 99999)" }
            }
            $baName = switch ($Provider)
            {
                "Azure" { "Contoso EA $i" }
                "AWS" { "AWS Org Account $i" }
                "GCP" { "GCP Billing Account $i" }
                "DataCenter" { "IT Cost Center $i" }
            }
            $billingAccounts += @{ Id = $baId; Name = $baName }
        }

        # 4-8 Sub-Accounts per provider with realistic names
        $subAccountNames = switch ($Provider)
        {
            "Azure" { @("Production Subscription", "Staging Subscription", "Development Subscription", "Shared Services Subscription", "Data Platform Subscription", "Security Subscription", "Networking Subscription", "App Team A Subscription") }
            "AWS" { @("prod-workloads", "staging-env", "dev-sandbox", "shared-services", "data-lake", "security-tools", "networking", "app-team-b") }
            "GCP" { @("prod-services", "staging-services", "dev-playground", "shared-infra", "analytics-platform", "ml-experiments", "networking", "frontend-apps") }
            "DataCenter" { @("Engineering", "Finance", "Operations", "Research", "Marketing", "IT Infrastructure", "Human Resources", "Executive") }
        }
        $subAccountCount = Get-Random -Minimum 4 -Maximum ([math]::Min(9, $subAccountNames.Count + 1))
        $subAccounts = @()
        for ($i = 0; $i -lt $subAccountCount; $i++)
        {
            $saName = $subAccountNames[$i]
            $saId = switch ($Provider)
            {
                "Azure" { "/subscriptions/$([guid]::NewGuid().ToString())" }
                "AWS" { New-AwsAccountId }
                "GCP" { "proj-$($Provider.ToLower())-$(Get-Random -Minimum 10000 -Maximum 99999)" }
                "DataCenter" { "BU-$(Get-Random -Minimum 100 -Maximum 999)" }
            }
            $subAccounts += @{ Id = $saId; Name = $saName; BillingAccount = $billingAccounts[$i % $billingAccounts.Count] }
        }

        # Billing profile IDs (consistent per provider)
        $billingProfileIds = @()
        for ($i = 1; $i -le 3; $i++)
        {
            $billingProfileIds += "BP-$(Get-Random -Minimum 10000 -Maximum 99999)"
        }

        # Resource Groups
        $resourceGroups = @("rg-production-001", "rg-staging-001", "rg-development-001", "rg-data-platform",
            "rg-shared-services", "rg-networking", "rg-security", "rg-analytics",
            "rg-app-team-a", "rg-app-team-b", "rg-ml-training", "rg-monitoring")

        # Pre-generate a pool of persistent resources
        $resourceCount = Get-Random -Minimum 150 -Maximum 400
        $resources = @()
        for ($i = 1; $i -le $resourceCount; $i++)
        {
            $service = Get-WeightedRandomService -Services $Config.Services
            $region = Get-RandomElement -Array $Config.Regions
            $resourceType = Get-RandomElement -Array $Config.ResourceTypes
            $subAccount = Get-RandomElement -Array $subAccounts
            $rg = Get-RandomElement -Array $resourceGroups
            $shortId = ([guid]::NewGuid().ToString()).Substring(0, 8)

            $resourceId = switch ($Provider)
            {
                "Azure" { "$($subAccount.Id)/resourceGroups/$rg/providers/$resourceType/$shortId" }
                "AWS" { "arn:aws:$(($resourceType -split '::')[1].ToLower()):$($region.Id):$($subAccount.Id):instance/i-$shortId" }
                "GCP" { "//$(($resourceType -split '/')[0])/projects/$($subAccount.Id)/zones/$($region.Id)-$(Get-RandomElement -Array @('a','b','c'))/instances/vm-$shortId" }
                "DataCenter" { "dc://$($region.Id)/$resourceType/$shortId" }
            }

            $resourceName = "$($service.Name.ToLower() -replace ' ','-')-$shortId"

            # Tags: ~80% of resources get tags, ~20% are untagged (for tag coverage analysis)
            $tagHash = @{}
            $hasTagsRoll = Get-Random -Maximum 100
            if ($hasTagsRoll -lt 80)
            {
                $tagHash = @{
                    "Environment"  = Get-RandomElement -Array @("Production", "Staging", "Development", "Test")
                    "Department"   = Get-RandomElement -Array @("Engineering", "Finance", "Operations", "Marketing", "Sales", "Research")
                    "CostCenter"   = "CC-$(Get-Random -Minimum 100 -Maximum 999)"
                    "BusinessUnit" = Get-RandomElement -Array @("BU-1", "BU-2", "BU-3", "BU-4")
                    "Application"  = Get-RandomElement -Array @("web-app", "api-service", "data-pipeline", "analytics", "backend", "frontend", "ml-training", "batch-jobs")
                    "Owner"        = Get-RandomElement -Array @("team-alpha", "team-beta", "platform", "data-team", "infra", "security-team", "devops", "sre")
                }

                # Azure-specific FinOps Hub tags on ~30% of tagged Azure resources
                if ($Provider -eq "Azure" -and (Get-Random -Maximum 100) -lt 30)
                {
                    $hubStorageSuffix = Get-Random -Minimum 1000 -Maximum 9999
                    $tagHash["ftk-tool"] = "FinOps hubs"
                    $tagHash["ftk-version"] = "0.8.0"
                    $tagHash["cm-resource-parent"] = "$($subAccount.Id)/resourceGroups/rg-finops-hub/providers/Microsoft.Storage/storageAccounts/stfinopshub$hubStorageSuffix"
                }

                # AWS-specific tags
                if ($Provider -eq "AWS")
                {
                    $tagHash["aws:createdBy"] = Get-RandomElement -Array @("CloudFormation", "Terraform", "CDK", "Console")
                }

                # GCP-specific tags
                if ($Provider -eq "GCP")
                {
                    $tagHash["goog-dm"] = Get-RandomElement -Array @("deployment-mgr", "terraform", "gcloud-cli")
                }
            }

            # VM SKU assignment (providers with VmSkus get instance types for VM compute services)
            $vmSku = $null
            $isVmResource = ($Provider -eq "Azure" -and $resourceType -eq "microsoft.compute/virtualmachines") -or
            ($Provider -eq "AWS" -and $resourceType -eq "AWS::EC2::Instance") -or
            ($Provider -eq "GCP" -and $resourceType -eq "compute.googleapis.com/Instance")
            if ($isVmResource -and $Config.VmSkus)
            {
                $vmSku = Get-RandomElement -Array $Config.VmSkus
            }

            # AHB eligibility: Azure VMs and SQL with ~40% eligible
            $ahbEligible = $false
            $ahbLicenseType = $null
            if ($Provider -eq "Azure" -and $resourceType -in @("microsoft.compute/virtualmachines", "microsoft.sql/servers"))
            {
                if ((Get-Random -Maximum 100) -lt 40)
                {
                    $ahbEligible = $true
                    $ahbLicenseType = if ($resourceType -eq "microsoft.sql/servers")
                    {
                        "SQL Server"
                    }
                    else
                    {
                        Get-RandomElement -Array @("Windows Server", "Windows Server", "SUSE Linux", "RHEL Linux")
                    }
                }
            }

            # Determine a base daily cost for this specific resource (varies +/-20% daily)
            $baseDailyCost = Get-RandomDecimal -Min $service.CostMin -Max $service.CostMax

            # SKU IDs (stable per resource)
            $skuId = "SKU-$(Get-Random -Minimum 100000 -Maximum 999999)"
            $skuPriceId = "PRICE-$(Get-Random -Minimum 100000 -Maximum 999999)"
            $skuMeterId = [guid]::NewGuid().ToString()

            $resources += @{
                ResourceId     = $resourceId
                ResourceName   = $resourceName
                ResourceType   = $resourceType
                Service        = $service
                Region         = $region
                SubAccount     = $subAccount
                ResourceGroup  = $rg
                Tags           = $tagHash
                BaseDailyCost  = $baseDailyCost
                SkuId          = $skuId
                SkuPriceId     = $skuPriceId
                SkuMeterId     = $skuMeterId
                VmSku          = $vmSku
                AhbEligible    = $ahbEligible
                AhbLicenseType = $ahbLicenseType
            }
        }

        # Pre-generate commitment discounts (multi-cloud)
        $commitments = @()
        $commitmentCount = switch ($Provider)
        {
            "Azure" { Get-Random -Minimum 8 -Maximum 16 }
            "AWS" { Get-Random -Minimum 5 -Maximum 12 }
            "GCP" { Get-Random -Minimum 3 -Maximum 8 }
            "DataCenter" { 0 }
        }
        for ($i = 1; $i -le $commitmentCount; $i++)
        {
            $commitType = Get-RandomElement -Array @("Reservation", "Savings Plan")
            $commitId = switch ($Provider)
            {
                "Azure"
                {
                    if ($commitType -eq "Reservation")
                    {
                        "/providers/Microsoft.Capacity/reservationOrders/$([guid]::NewGuid().ToString())"
                    }
                    else
                    {
                        "/providers/Microsoft.BillingBenefits/savingsPlanOrders/$([guid]::NewGuid().ToString())"
                    }
                }
                "AWS" { "arn:aws:savingsplans::$(New-AwsAccountId):savingsplan/sp-$([guid]::NewGuid().ToString().Substring(0,8))" }
                "GCP" { "projects/test-project/commitments/$([guid]::NewGuid().ToString().Substring(0,8))" }
                default { "" }
            }
            $skuOrderId = [guid]::NewGuid().ToString()
            $skuTerm = [string](Get-RandomElement -Array @(12, 36))  # 1 year or 3 years in months

            $commitments += @{
                Id         = $commitId
                Name       = "$($commitType -replace ' ','')-$(Get-Random -Minimum 1000 -Maximum 9999)"
                Type       = $commitType
                # FOCUS spec: Reservation = "Usage" (committed usage), Savings Plan = "Spend" (committed spend)
                Category   = if ($commitType -eq "Reservation") { "Usage" } else { "Spend" }
                SkuOrderId = $skuOrderId
                SkuTerm    = $skuTerm
            }
        }

        # Invoice IDs per billing period (populated lazily)
        $invoiceIds = @{}

        # Marketplace publishers
        $marketplacePublishers = @(
            "Palo Alto Networks", "Fortinet", "Check Point", "Zscaler", "Cisco Meraki",
            "Databricks", "Snowflake", "Confluent",
            "Datadog", "Elastic", "Dynatrace", "New Relic",
            "HashiCorp", "Red Hat", "SUSE",
            "Twilio SendGrid", "MongoDB", "Salesforce", "ServiceNow"
        )

        return @{
            BillingAccounts       = $billingAccounts
            SubAccounts           = $subAccounts
            BillingProfileIds     = $billingProfileIds
            ResourceGroups        = $resourceGroups
            Resources             = $resources
            Commitments           = $commitments
            InvoiceIds            = $invoiceIds
            MarketplacePublishers = $marketplacePublishers
        }
    }

    # ============================================================================
    # Row Generation
    # ============================================================================

    function New-FocusRow
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [string]$Provider,
            [datetime]$ChargeDate,
            [hashtable]$Config,
            [hashtable]$Identity,
            [double]$ScaleFactor,
            [version]$FocusVer,
            [switch]$IncludeCommitments,
            [switch]$IncludeHybridBenefit
        )

        # Pick a persistent resource
        $res = Get-RandomElement -Array $Identity.Resources
        $service = $res.Service
        $region = $res.Region
        $subAccount = $res.SubAccount
        $billingAccount = $subAccount.BillingAccount

        # Daily cost variation: base +/- 20% with slight upward trend over months
        $monthIndex = (($ChargeDate.Year - $StartDate.Year) * 12 + $ChargeDate.Month - $StartDate.Month)
        $trendFactor = 1.0 + ($monthIndex * 0.02)  # 2% growth per month
        $jitter = 0.80 + (Get-Random -Maximum 41) / 100.0  # 0.80 to 1.20
        $listCost = [math]::Round($res.BaseDailyCost * $trendFactor * $jitter * $ScaleFactor, 2)
        if ($listCost -lt 0.01) { $listCost = 0.01 }

        # On-demand cost: same as list cost (before any discounts)
        $onDemandCost = $listCost

        # Negotiated/EA discount: 5-30% off list for ~60% of rows
        $negotiatedDiscountPct = 0
        if ((Get-Random -Maximum 100) -lt 60)
        {
            $negotiatedDiscountPct = Get-Random -Minimum 5 -Maximum 31
        }
        $contractedCost = [math]::Round($listCost * (100 - $negotiatedDiscountPct) / 100, 2)
        $billedCost = $contractedCost
        $effectiveCost = $contractedCost

        $pricingQuantity = Get-RandomDecimal -Min 1 -Max 1000
        $consumedQuantity = $pricingQuantity

        $chargePeriodStart = $ChargeDate.Date
        $chargePeriodEnd = $ChargeDate.Date.AddDays(1)
        $billingPeriodStart = [datetime]::new($ChargeDate.Year, $ChargeDate.Month, 1)
        $billingPeriodEnd = $billingPeriodStart.AddMonths(1)

        # Charge category distribution: 85% Usage, 8% Purchase, 3% Tax, 2% Credit, 2% Adjustment
        $catRoll = Get-Random -Maximum 100
        $chargeCategory = if ($catRoll -lt 85) { "Usage" }
        elseif ($catRoll -lt 93) { "Purchase" }
        elseif ($catRoll -lt 96) { "Tax" }
        elseif ($catRoll -lt 98) { "Credit" }
        else { "Adjustment" }

        # ChargeClass: mostly null, ~3% are corrections
        $chargeClass = $null
        if ((Get-Random -Maximum 100) -lt 3)
        {
            $chargeClass = "Correction"
        }

        # ChargeFrequency based on ChargeCategory
        $chargeFrequency = switch ($chargeCategory)
        {
            "Purchase" { Get-RandomElement -Array @("One-Time", "Recurring") }
            "Tax" { "Recurring" }
            "Credit" { "One-Time" }
            default { "Usage-Based" }
        }

        # Credits and Adjustments are negative
        if ($chargeCategory -in @("Credit", "Adjustment"))
        {
            $listCost = - [math]::Abs($listCost) * 0.1  # Credits are ~10% of normal costs
            $contractedCost = $listCost
            $billedCost = $listCost
            $effectiveCost = $listCost
            $onDemandCost = [math]::Abs($listCost)
        }

        # AvailabilityZone: vary a/b/c
        $az = "$($region.Id)-$(Get-RandomElement -Array @('a', 'b', 'c'))"

        # === PRICING CATEGORY (start with Standard/on-demand) ===
        $pricingCategory = "Standard"

        # === COMMITMENT DISCOUNT SIMULATION (multi-cloud) ===
        $commitmentDiscountId = $null
        $commitmentDiscountName = $null
        $commitmentDiscountCategory = $null
        $commitmentDiscountType = $null
        $commitmentDiscountStatus = $null
        $commitmentDiscountQuantity = $null
        $commitmentDiscountUnit = $null
        $x_SkuOrderId = $null
        $x_SkuTerm = $null

        # 30% chance of commitment-covered usage (Azure/AWS/GCP - not DataCenter)
        if ($IncludeCommitments -and $Provider -ne "DataCenter" -and $chargeCategory -eq "Usage" -and
            $Identity.Commitments.Count -gt 0 -and (Get-Random -Maximum 100) -lt 30)
        {

            $commitment = Get-RandomElement -Array $Identity.Commitments
            $commitmentDiscountId = $commitment.Id
            $commitmentDiscountName = $commitment.Name
            $commitmentDiscountCategory = $commitment.Category
            $commitmentDiscountType = $commitment.Type
            $x_SkuOrderId = $commitment.SkuOrderId
            $x_SkuTerm = $commitment.SkuTerm
            $pricingCategory = "Committed"

            # 85% utilization - most are Used, some Unused
            if ((Get-Random -Maximum 100) -lt 85)
            {
                $commitmentDiscountStatus = "Used"
                $effectiveCost = [math]::Round($contractedCost * 0.40, 2)  # 60% savings on contracted
                $billedCost = 0  # Prepaid
            }
            else
            {
                $commitmentDiscountStatus = "Unused"
                $effectiveCost = [math]::Round($contractedCost * 0.60, 2)  # Wasted commitment
                $billedCost = $effectiveCost
            }

            $commitmentDiscountQuantity = $pricingQuantity
            $commitmentDiscountUnit = $service.PricingUnit
        }

        # === COMMITMENT PURCHASE ROWS (for invoicing page) ===
        if ($IncludeCommitments -and $Provider -ne "DataCenter" -and $chargeCategory -eq "Purchase" -and
            $Identity.Commitments.Count -gt 0 -and (Get-Random -Maximum 100) -lt 50)
        {

            $commitment = Get-RandomElement -Array $Identity.Commitments
            $commitmentDiscountId = $commitment.Id
            $commitmentDiscountName = $commitment.Name
            $commitmentDiscountCategory = $commitment.Category
            $commitmentDiscountType = $commitment.Type
            $x_SkuOrderId = $commitment.SkuOrderId
            $x_SkuTerm = $commitment.SkuTerm
            $pricingCategory = "Committed"
        }

        # === SPOT / DYNAMIC INSTANCE SIMULATION ===
        $spotEligibleServices = @("Virtual Machines", "Azure Kubernetes Service", "Amazon EC2", "Amazon EKS", "Compute Engine", "Google Kubernetes Engine", "VMware vSphere")
        if ($chargeCategory -eq "Usage" -and $null -eq $commitmentDiscountId -and $service.Name -in $spotEligibleServices)
        {
            if ((Get-Random -Maximum 100) -lt 15)
            {
                $pricingCategory = "Dynamic"

                $spotDiscount = Get-Random -Minimum 60 -Maximum 90
                $effectiveCost = [math]::Round($listCost * (100 - $spotDiscount) / 100, 2)
                $billedCost = $effectiveCost
                $contractedCost = $effectiveCost
            }
        }

        # === AZURE HYBRID BENEFIT SIMULATION ===
        $x_SkuMeterCategory = $null
        $x_SkuMeterSubcategory = $null
        $x_SkuMeterName = $null
        $x_SkuInstanceType = $null
        $x_SkuCoreCount = $null
        $x_SkuLicenseStatus = $null
        $x_SkuLicenseQuantity = $null
        $x_SkuLicenseType = $null
        $x_SkuDescription = $null

        if ($Provider -eq "Azure")
        {
            if ($res.VmSku)
            {
                $vmSku = $res.VmSku
                $x_SkuInstanceType = $vmSku.InstanceType
                $x_SkuCoreCount = $vmSku.Cores
                $x_SkuDescription = $vmSku.Description
                $x_SkuMeterCategory = "Virtual Machines"
                $x_SkuMeterSubcategory = "$($vmSku.InstanceType) Series"
                $x_SkuMeterName = $vmSku.MeterName
            }
            elseif ($service.Category -eq "Compute")
            {
                $x_SkuMeterCategory = $service.Name
                $x_SkuMeterSubcategory = $service.Subcategory
                $x_SkuDescription = "$($service.Name) - Standard"
            }
            elseif ($service.Category -eq "Databases")
            {
                $x_SkuMeterCategory = $service.Name
                $x_SkuMeterSubcategory = "Compute"
                $x_SkuDescription = "$($service.Name) - Standard Tier"
            }
            else
            {
                $x_SkuDescription = "$($service.Name) - $($service.Subcategory)"
            }

            # AHB columns — set x_SkuMeterSubcategory patterns that the ingestion KQL uses to derive
            # x_SkuLicenseType and x_SkuLicenseStatus (the KQL re-derives these, so raw values are overwritten)
            if ($IncludeHybridBenefit -and $res.AhbEligible -and $chargeCategory -eq "Usage")
            {
                $x_SkuLicenseType = $res.AhbLicenseType

                if ((Get-Random -Maximum 100) -lt 60)
                {
                    # AHB Enabled — ingestion KQL checks: x_SkuMeterSubcategory contains 'Azure Hybrid Benefit'
                    $x_SkuLicenseStatus = "Enabled"
                    $x_SkuLicenseQuantity = if ($res.VmSku) { $res.VmSku.Cores } else { Get-RandomElement -Array @(2, 4, 8, 16) }
                    $licenseSavings = [math]::Round([math]::Abs($effectiveCost) * 0.40, 2)
                    $effectiveCost = [math]::Max(0.01, [math]::Round($effectiveCost - $licenseSavings, 2))

                    if ($res.AhbLicenseType -eq "SQL Server")
                    {
                        $x_SkuMeterSubcategory = "SQL Server Azure Hybrid Benefit"
                    }
                    elseif ($res.VmSku)
                    {
                        # Real Azure pattern: "Dv5 Series Windows" + BYOL image type
                        $x_SkuMeterSubcategory = "$($vmSku.InstanceType) Series Azure Hybrid Benefit"
                    }
                }
                else
                {
                    # AHB Not Enabled — ingestion KQL checks: x_SkuMeterSubcategory contains 'Windows'
                    $x_SkuLicenseStatus = "Not Enabled"
                    $x_SkuLicenseQuantity = 0

                    if ($res.AhbLicenseType -eq "SQL Server")
                    {
                        $x_SkuMeterCategory = "SQL Database"
                        $x_SkuMeterSubcategory = "Compute"
                    }
                    elseif ($res.VmSku)
                    {
                        # Real Azure pattern: "Dv5 Series Windows" (contains 'Windows' but not 'Azure Hybrid Benefit')
                        $x_SkuMeterSubcategory = "$($vmSku.InstanceType) Series Windows"
                    }
                }
            }
        }

        # === UNIT PRICES (derived from costs / quantity) ===
        # Calculated AFTER all cost modifications to maintain FOCUS cost invariants:
        #   ListCost = ListUnitPrice * PricingQuantity
        #   ContractedCost = ContractedUnitPrice * PricingQuantity
        $listUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($listCost / $pricingQuantity, 2) } else { 0 }
        $contractedUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($contractedCost / $pricingQuantity, 2) } else { 0 }
        $effectiveUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($effectiveCost / $pricingQuantity, 2) } else { 0 }
        $billedUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($billedCost / $pricingQuantity, 2) } else { 0 }
        $onDemandUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($onDemandCost / $pricingQuantity, 2) } else { 0 }

        # === DATA QUALITY ANOMALIES (~2% of rows) ===
        # Anomaly rows use ChargeClass=Correction to exempt them from FOCUS cost invariant rules.
        # This is documented via x_SourceChanges for the data quality dashboard page.
        $x_SourceChanges = $null
        $qualityRoll = Get-Random -Maximum 100
        if ($qualityRoll -eq 0)
        {
            # Effective > Contracted (anomaly) - mark as Correction
            $effectiveCost = [math]::Round($contractedCost * 1.1, 2)
            $effectiveUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($effectiveCost / $pricingQuantity, 2) } else { 0 }
            $x_SourceChanges = "CostAdjustment"
            $chargeClass = "Correction"
        }
        elseif ($qualityRoll -eq 1)
        {
            # Contracted > List (anomaly) - mark as Correction
            $contractedCost = [math]::Round($listCost * 1.05, 2)
            $contractedUnitPrice = if ($pricingQuantity -ne 0) { [math]::Round($contractedCost / $pricingQuantity, 2) } else { 0 }
            $x_SourceChanges = "PriceCorrection"
            $chargeClass = "Correction"
        }

        # Invoice ID: stable per billing period
        # Credits and adjustments typically do not have invoices (FOCUS spec compliance)
        $invoiceId = $null
        if ($chargeCategory -notin @("Credit", "Adjustment") -or $chargeClass -eq "Correction")
        {
            $invoiceKey = "$($billingAccount.Id)-$($billingPeriodStart.ToString('yyyyMM'))"
            if (-not $Identity.InvoiceIds.ContainsKey($invoiceKey))
            {
                $Identity.InvoiceIds[$invoiceKey] = "INV-$($billingPeriodStart.ToString('yyyyMM'))-$(Get-Random -Minimum 10000 -Maximum 99999)"
            }
            $invoiceId = $Identity.InvoiceIds[$invoiceKey]
        }

        # Tags as JSON
        $tagsJson = if ($res.Tags.Count -gt 0) { ($res.Tags | ConvertTo-Json -Compress) } else { '{}' }

        # Publisher info
        $isMarketplace = [bool]$service.IsMarketplace
        $publisherName = if ($isMarketplace) { Get-RandomElement -Array $Identity.MarketplacePublishers } else { $Config.ServiceProviderName }

        # === CAPACITY RESERVATION SIMULATION (v1.3+) ===
        $capacityReservationId = $null
        $capacityReservationStatus = $null
        # ~10% of Usage rows for cloud providers with VM services get capacity reservations
        if ($chargeCategory -eq 'Usage' -and $null -eq $commitmentDiscountId -and
            $Provider -ne 'DataCenter' -and $service.Category -eq 'Compute' -and
            (Get-Random -Maximum 100) -lt 10)
        {
            $capacityReservationId = "/subscriptions/$($subAccount.Id)/providers/Microsoft.Compute/capacityReservationGroups/crg-$(Get-Random -Minimum 1000 -Maximum 9999)"
            $capacityReservationStatus = if ((Get-Random -Maximum 100) -lt 85) { 'Used' } else { 'Unused' }
        }

        # === SKU METER (v1.3+) — describes what the SKU is metering ===
        # For Azure VMs, use the VM SKU meter name (e.g., "D4s v5/Hour") so the CPU
        # architecture dashboard can classify by AMD/Intel/Arm64 using SKU naming patterns.
        $skuMeter = if ($res.VmSku)
        {
            "$($res.VmSku.MeterName)/Hour"
        }
        else
        {
            switch ($service.Category)
            {
                'Compute' { 'Compute Usage' }
                'Storage' { 'Block Volume Usage' }
                'Databases' { 'Database Usage' }
                'Networking' { 'Data Transfer' }
                default { 'API Requests' }
            }
        }

        # === CONTRACT APPLIED (v1.3+) — JSON bridging Cost rows to Contract Commitment dataset ===
        $contractApplied = $null
        if ($commitmentDiscountId -and $pricingCategory -eq 'Committed')
        {
            $contractApplied = (@{
                    ContractId     = $x_SkuOrderId
                    ContractType   = $commitmentDiscountType
                    ContractTerm   = $x_SkuTerm
                    ContractStatus = $commitmentDiscountStatus
                } | ConvertTo-Json -Compress)
        }

        # === SPLIT COST ALLOCATION (v1.3+) — simulates shared resource cost splitting ===
        # ~10% of container service rows (AKS, EKS, GKE) get allocation data to test the
        # split cost allocation dashboard features.
        $allocatedMethodDetails = $null
        $allocatedMethodId = $null
        $allocatedResourceId = $null
        $allocatedResourceName = $null
        $allocatedResourceType = $null
        $allocatedTags = $null

        $allocationEligibleServices = @('Azure Kubernetes Service', 'Amazon EKS', 'Google Kubernetes Engine')
        if ($chargeCategory -eq 'Usage' -and $service.Name -in $allocationEligibleServices -and
            (Get-Random -Maximum 100) -lt 10)
        {
            $allocatedNamespace = Get-RandomElement -Array @('frontend', 'backend', 'data-pipeline', 'monitoring', 'ml-inference', 'batch-jobs')
            $allocatedMethodId = 'ProportionalByCPU'
            $allocatedMethodDetails = (@{
                    Method     = 'Proportional'
                    SplitBy    = 'CPU Requests'
                    Namespace  = $allocatedNamespace
                    Percentage = [math]::Round((Get-Random -Minimum 5 -Maximum 60), 0)
                } | ConvertTo-Json -Compress)
            $allocatedResourceId = "$($res.ResourceId)/namespaces/$allocatedNamespace"
            $allocatedResourceName = "$($res.ResourceName)/$allocatedNamespace"
            $allocatedResourceType = switch ($Provider)
            {
                'Azure' { 'microsoft.containerservice/managedclusters/namespaces' }
                'AWS' { 'AWS::EKS::Cluster::Namespace' }
                'GCP' { 'container.googleapis.com/Cluster/Namespace' }
                default { $res.ResourceType }
            }
            $allocatedTags = (@{
                    Namespace = $allocatedNamespace
                    Team      = Get-RandomElement -Array @('team-alpha', 'team-beta', 'platform', 'data-team')
                } | ConvertTo-Json -Compress)
        }

        # === SKU PRICE DETAILS (v1.2+) — JSON with FOCUS-defined properties ===
        $skuPriceDetails = $null
        if ($chargeCategory -in @('Usage', 'Purchase'))
        {
            $spd = [ordered]@{}
            if ($res.VmSku)
            {
                $spd['CoreCount'] = $res.VmSku.Cores
                $spd['OperatingSystem'] = Get-RandomElement -Array @('Linux', 'Windows')
            }
            elseif ($service.Category -eq 'Storage')
            {
                $spd['DiskSpace'] = Get-RandomElement -Array @(32, 64, 128, 256, 512, 1024)
                $spd['DiskType'] = Get-RandomElement -Array @('SSD', 'HDD')
                $spd['Redundancy'] = Get-RandomElement -Array @('Local', 'Zonal', 'Global')
                $spd['StorageClass'] = Get-RandomElement -Array @('Hot', 'Cool', 'Archive')
            }
            elseif ($service.Category -eq 'Databases')
            {
                $spd['CoreCount'] = Get-RandomElement -Array @(2, 4, 8, 16)
            }
            if ($spd.Count -gt 0)
            {
                $skuPriceDetails = ($spd | ConvertTo-Json -Compress)
            }
        }

        # Build the row as an ordered hashtable, then select version-appropriate columns
        $row = [ordered]@{
            # ===================== Mandatory FOCUS columns (all versions) =====================
            BilledCost                         = $billedCost
            BillingAccountId                   = $billingAccount.Id
            BillingAccountName                 = $billingAccount.Name
            BillingCurrency                    = $Config.BillingCurrency
            BillingPeriodEnd                   = Get-IsoDateTime -Date $billingPeriodEnd
            BillingPeriodStart                 = Get-IsoDateTime -Date $billingPeriodStart
            ChargeCategory                     = $chargeCategory
            ChargeClass                        = $chargeClass
            ChargeDescription                  = "$($service.Name) usage in $($region.Name)"
            ChargeFrequency                    = $chargeFrequency
            ChargePeriodEnd                    = Get-IsoDateTime -Date $chargePeriodEnd
            ChargePeriodStart                  = Get-IsoDateTime -Date $chargePeriodStart
            ContractedCost                     = $contractedCost
            EffectiveCost                      = $effectiveCost
            InvoiceIssuerName                  = $Config.InvoiceIssuerName
            ListCost                           = $listCost
            ListUnitPrice                      = $listUnitPrice
            PricingQuantity                    = $pricingQuantity
            PricingUnit                        = $service.PricingUnit
            # ProviderName is mandatory in FOCUS v1.0-v1.2; renamed to ServiceProviderName in v1.3
            ProviderName                       = $Config.ProviderName
            RegionId                           = $region.Id
            RegionName                         = $region.Name
            ResourceId                         = $res.ResourceId
            ResourceName                       = $res.ResourceName
            ResourceType                       = $res.ResourceType
            ServiceCategory                    = $service.Category
            ServiceName                        = $service.Name
            SkuId                              = $res.SkuId
            SkuPriceId                         = $res.SkuPriceId
            SubAccountId                       = $subAccount.Id
            SubAccountName                     = $subAccount.Name
            Tags                               = $tagsJson

            # ===================== Conditional FOCUS columns (all versions) =====================
            AvailabilityZone                   = $az
            CommitmentDiscountCategory         = $commitmentDiscountCategory
            CommitmentDiscountId               = $commitmentDiscountId
            CommitmentDiscountName             = $commitmentDiscountName
            CommitmentDiscountStatus           = $commitmentDiscountStatus
            CommitmentDiscountType             = $commitmentDiscountType
            ConsumedQuantity                   = $consumedQuantity
            ConsumedUnit                       = $service.ConsumedUnit
            ContractedUnitPrice                = $contractedUnitPrice
            PricingCategory                    = $pricingCategory
            ServiceSubcategory                 = $service.Subcategory

            # ===================== Version-specific FOCUS columns =====================
            # All columns included in the ordered hashtable upfront so Export-Parquet sees
            # a consistent 80-column schema from the very first row.

            # v1.1+
            CommitmentDiscountQuantity         = if ($FocusVer -ge [version]'1.1') { $commitmentDiscountQuantity } else { [double]0 }
            CommitmentDiscountUnit             = if ($FocusVer -ge [version]'1.1') { $commitmentDiscountUnit } else { '' }

            # v1.2+
            BillingAccountType                 = if ($FocusVer -ge [version]'1.2') { $Config.BillingAccountType } else { '' }
            InvoiceId                          = if ($FocusVer -ge [version]'1.2') { $invoiceId } else { '' }
            PricingCurrency                    = if ($FocusVer -ge [version]'1.2') { $Config.BillingCurrency } else { '' }
            PricingCurrencyContractedUnitPrice = if ($FocusVer -ge [version]'1.2') { $contractedUnitPrice } else { $null }
            PricingCurrencyEffectiveCost       = if ($FocusVer -ge [version]'1.2') { $effectiveCost } else { $null }
            PricingCurrencyListUnitPrice       = if ($FocusVer -ge [version]'1.2') { $listUnitPrice } else { $null }
            SkuPriceDetails                    = if ($FocusVer -ge [version]'1.2') { $skuPriceDetails } else { $null }
            SubAccountType                     = if ($FocusVer -ge [version]'1.2') { $Config.SubAccountType } else { '' }

            # v1.3+
            CapacityReservationId              = if ($FocusVer -ge [version]'1.3') { $capacityReservationId } else { $null }
            CapacityReservationStatus          = if ($FocusVer -ge [version]'1.3') { $capacityReservationStatus } else { $null }
            ContractApplied                    = if ($FocusVer -ge [version]'1.3') { $contractApplied } else { $null }
            HostProviderName                   = if ($FocusVer -ge [version]'1.3') { $Config.HostProviderName } else { '' }
            ServiceProviderName                = if ($FocusVer -ge [version]'1.3') { $Config.ServiceProviderName } else { '' }
            SkuMeter                           = if ($FocusVer -ge [version]'1.3') { $skuMeter } else { '' }

            # v1.3+ Allocation columns (Recommended/Conditional)
            # Populated for shared/container services (~10% of AKS/EKS/GKE rows) to simulate split cost allocation.
            AllocatedMethodDetails             = if ($FocusVer -ge [version]'1.3') { $allocatedMethodDetails } else { $null }
            AllocatedMethodId                  = if ($FocusVer -ge [version]'1.3') { $allocatedMethodId } else { $null }
            AllocatedResourceId                = if ($FocusVer -ge [version]'1.3') { $allocatedResourceId } else { $null }
            AllocatedResourceName              = if ($FocusVer -ge [version]'1.3') { $allocatedResourceName } else { $null }
            AllocatedResourceType              = if ($FocusVer -ge [version]'1.3') { $allocatedResourceType } else { $null }
            AllocatedTags                      = if ($FocusVer -ge [version]'1.3') { $allocatedTags } else { $null }

            # ===================== FinOps Hub / Dashboard required columns =====================
            x_BillingAccountId                 = $billingAccount.Id
            x_BillingAccountAgreement          = $Config.BillingAccountAgreement
            x_BillingProfileId                 = (Get-RandomElement -Array $Identity.BillingProfileIds)
            x_ResourceGroupName                = $res.ResourceGroup
            x_ResourceType                     = $res.ResourceType

            # Publisher
            PublisherName                      = $publisherName
            x_PublisherCategory                = if ($isMarketplace) { 'Marketplace' } else { $Provider }

            # Unit prices (dashboard discount analysis)
            x_EffectiveUnitPrice               = $effectiveUnitPrice
            x_BilledUnitPrice                  = $billedUnitPrice
            x_OnDemandCost                     = $onDemandCost
            x_OnDemandUnitPrice                = $onDemandUnitPrice

            # SKU columns
            x_SkuDescription                   = $x_SkuDescription
            x_SkuInstanceType                  = $x_SkuInstanceType
            x_SkuCoreCount                     = $x_SkuCoreCount
            x_SkuMeterCategory                 = $x_SkuMeterCategory
            x_SkuMeterSubcategory              = $x_SkuMeterSubcategory
            x_SkuMeterName                     = $x_SkuMeterName
            x_SkuMeterId                       = $res.SkuMeterId
            x_SkuOfferId                       = if ($Provider -eq 'Azure') { 'MS-AZR-0017P' } else { '' }
            x_SkuLicenseStatus                 = $x_SkuLicenseStatus
            x_SkuLicenseQuantity               = $x_SkuLicenseQuantity
            x_SkuLicenseType                   = $x_SkuLicenseType

            # Commitment linkage
            x_SkuOrderId                       = $x_SkuOrderId
            x_SkuTerm                          = $x_SkuTerm

            # Pricing detail
            x_PricingBlockSize                 = $service.PricingBlockSize
            x_PricingUnitDescription           = $service.PricingUnitDescription

            # Source metadata (required by ingestion pipeline)
            x_SourceName                       = "test-data-generator"
            x_SourceProvider                   = "Microsoft"
            x_SourceType                       = "FocusCost"
            x_SourceVersion                    = "1.0-preview(v1)"

            # Data quality / metadata
            x_SourceChanges                    = $x_SourceChanges
            x_CloudProvider                    = $Provider
            x_FocusVersion                     = $FocusVersion
            x_IngestionTime                    = (Get-IsoDateTime -Date (Get-Date))
        }

        return [PSCustomObject]$row
    }

    # ============================================================================
    # Additional FOCUS Dataset Generators
    # ============================================================================
    # These functions generate data for the non-Cost FOCUS datasets that the
    # FinOps Hub ingestion pipeline expects:
    #   - Prices (Azure EA/MCA price sheet)
    #   - CommitmentDiscountUsage (Azure reservation details)
    #   - Recommendations (Azure reservation recommendations)
    #   - Transactions (Azure reservation transactions)
    #
    # These datasets are Azure-only (Cost Management exports). They use the same
    # persistent identity pool so that reservation IDs, subscription IDs, and
    # meter IDs are consistent with the Cost/Usage data.
    # ============================================================================

    function New-PriceRow
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [hashtable]$Config,
            [hashtable]$Identity,
            [hashtable]$ServiceDef,
            [hashtable]$ResourceDef,
            [string]$PriceType,
            [string]$Term
        )

        $billingAccount = (Get-RandomElement -Array $Identity.BillingAccounts)
        $region = $ResourceDef.Region

        # Realistic unit and market prices
        $unitPrice = Get-RandomDecimal -Min ([decimal]$ServiceDef.CostMin / 100) -Max ([decimal]$ServiceDef.CostMax / 10)
        $marketPrice = [math]::Round($unitPrice * (Get-RandomDecimal -Min 1.0 -Max 1.3), 6)
        $basePrice = [math]::Round($marketPrice * (Get-RandomDecimal -Min 0.9 -Max 1.0), 6)

        # SKU IDs
        $meterId = $ResourceDef.SkuMeterId
        $productId = "DZH318Z0$((Get-Random -Minimum 1000 -Maximum 9999))"
        $skuId = $ResourceDef.SkuId

        # Meter details from service
        $meterCategory = if ($ResourceDef.VmSku) { "Virtual Machines" } else { $ServiceDef.Name }
        $meterSubCategory = if ($ResourceDef.VmSku) { "$($ResourceDef.VmSku.InstanceType) Series" } else { $ServiceDef.Subcategory }
        $meterName = if ($ResourceDef.VmSku) { $ResourceDef.VmSku.MeterName } else { "$($ServiceDef.Name) - Standard" }
        $meterRegion = $region.Name
        $meterType = if ($PriceType -eq 'Consumption') { 'Consumption' } elseif ($PriceType -eq 'ReservedInstance') { 'Reservation' } else { 'SavingsPlan' }

        $effectiveStart = [datetime]::new($StartDate.Year, $StartDate.Month, 1)
        $effectiveEnd = $effectiveStart.AddYears(1)

        $row = [ordered]@{
            BasePrice          = [double]$basePrice
            BillingAccountId   = $billingAccount.Id
            BillingAccountName = $billingAccount.Name
            BillingCurrency    = $Config.BillingCurrency
            BillingProfileId   = (Get-RandomElement -Array $Identity.BillingProfileIds)
            BillingProfileName = "Billing Profile 1"
            Currency           = $Config.BillingCurrency
            CurrencyCode       = $Config.BillingCurrency
            EffectiveEndDate   = $effectiveEnd.ToString("yyyy-MM-ddT00:00:00Z")
            EffectiveStartDate = $effectiveStart.ToString("yyyy-MM-ddT00:00:00Z")
            EnrollmentNumber   = $billingAccount.Id
            IncludedQuantity   = [double]0
            MarketPrice        = [double]$marketPrice
            MeterCategory      = $meterCategory
            MeterId            = $meterId
            MeterName          = $meterName
            MeterRegion        = $meterRegion
            MeterSubCategory   = $meterSubCategory
            MeterType          = $meterType
            OfferID            = "MS-AZR-0017P"
            PartNumber         = "PT-$(Get-Random -Minimum 10000 -Maximum 99999)"
            PriceType          = $PriceType
            Product            = "$meterCategory - $meterName"
            ProductId          = $productId
            ServiceFamily      = $ServiceDef.Category
            SkuId              = $skuId
            Term               = $Term
            TierMinimumUnits   = [double]0
            UnitOfMeasure      = $ServiceDef.PricingUnitDescription
            UnitPrice          = [double]$unitPrice
            x_SourceName       = "test-data-generator"
            x_SourceProvider   = "Microsoft"
            x_SourceType       = "PriceSheet"
            x_SourceVersion    = "2023-05-01"
        }

        return [PSCustomObject]$row
    }

    function New-CommitmentDiscountUsageRow
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [hashtable]$Commitment,
            [datetime]$UsageDate,
            [hashtable]$ResourceDef
        )

        # Split commitment ID to extract order and reservation IDs
        # Azure format: /providers/Microsoft.Capacity/reservationOrders/{orderId}
        $orderId = $Commitment.SkuOrderId
        $reservationId = [guid]::NewGuid().ToString()

        # Hours in a day = 24; simulate utilization 70-100%
        $reservedHours = [double]24
        $utilizationPct = (Get-Random -Minimum 70 -Maximum 101) / 100.0
        $usedHours = [math]::Round($reservedHours * $utilizationPct, 2)

        # Instance flexibility
        $flexGroup = if ($ResourceDef.VmSku) { "$($ResourceDef.VmSku.InstanceType) Series" } else { "Standard" }
        $flexRatio = Get-RandomElement -Array @([double]1.0, [double]0.5, [double]2.0, [double]4.0)

        # SkuName from resource
        $skuName = if ($ResourceDef.VmSku) { $ResourceDef.VmSku.InstanceType } else { "Standard_D4s_v5" }

        $row = [ordered]@{
            InstanceFlexibilityGroup = $flexGroup
            InstanceFlexibilityRatio = $flexRatio
            InstanceId               = $ResourceDef.ResourceId
            Kind                     = "reservation"
            ReservationId            = $reservationId
            ReservationOrderId       = $orderId
            ReservedHours            = $reservedHours
            SkuName                  = $skuName
            TotalReservedQuantity    = $reservedHours
            UsageDate                = $UsageDate.ToString("yyyy-MM-ddT00:00:00Z")
            UsedHours                = $usedHours
            x_SourceName             = "test-data-generator"
            x_SourceProvider         = "Microsoft"
            x_SourceType             = "ReservationDetails"
            x_SourceVersion          = "2024-03-01"
        }

        return [PSCustomObject]$row
    }

    function New-RecommendationRow
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [hashtable]$ResourceDef,
            [datetime]$RecommendationDate
        )

        $subAccount = $ResourceDef.SubAccount
        $region = $ResourceDef.Region

        # Lookback period
        $lookBackPeriod = Get-RandomElement -Array @("Last7Days", "Last30Days", "Last60Days")
        $lookBackDays = switch ($lookBackPeriod) { "Last7Days" { 7 } "Last30Days" { 30 } "Last60Days" { 60 } }
        $firstUsageDate = $RecommendationDate.AddDays(-$lookBackDays)

        # Cost projections
        $costWithoutRI = Get-RandomDecimal -Min 500 -Max 50000
        $netSavings = [math]::Round($costWithoutRI * (Get-Random -Minimum 15 -Maximum 45) / 100.0, 2)
        $totalCostWithRI = [math]::Round($costWithoutRI - $netSavings, 2)

        # Recommended quantities
        $recommendedQty = [double](Get-Random -Minimum 1 -Maximum 20)
        $recommendedQtyNormalized = [math]::Round($recommendedQty * (Get-RandomElement -Array @([double]1, [double]2, [double]4, [double]8)), 2)

        # Flexibility
        $flexGroup = if ($ResourceDef.VmSku) { "$($ResourceDef.VmSku.InstanceType) Series" } else { "Standard" }
        $flexRatio = Get-RandomElement -Array @([double]1.0, [double]0.5, [double]2.0, [double]4.0)
        $normalizedSize = if ($ResourceDef.VmSku) { $ResourceDef.VmSku.InstanceType } else { "Standard_D4s_v5" }
        $skuName = $normalizedSize
        $term = Get-RandomElement -Array @("P1Y", "P3Y")
        $scope = Get-RandomElement -Array @("Shared", "Single")

        $effectiveCostBefore = $costWithoutRI
        $effectiveCostAfter = $totalCostWithRI
        $effectiveCostSavings = $netSavings

        # x_RecommendationDetails as JSON string (ADX will parse it as dynamic)
        $recoDetails = @{
            CommitmentDiscountNormalizedGroup = $flexGroup
            CommitmentDiscountNormalizedRatio = $flexRatio
            CommitmentDiscountNormalizedSize  = $normalizedSize
            CommitmentDiscountResourceType    = $ResourceDef.ResourceType
            CommitmentDiscountScope           = $scope
            LookbackPeriodDuration            = $lookBackPeriod
            LookbackPeriodStart               = $firstUsageDate.ToString("yyyy-MM-ddT00:00:00Z")
            RecommendedQuantity               = $recommendedQty
            RecommendedQuantityNormalized     = $recommendedQtyNormalized
            RegionId                          = $region.Id
            RegionName                        = $region.Name
            SkuMeterId                        = $ResourceDef.SkuMeterId
            SkuSize                           = $normalizedSize
            SkuTerm                           = $term
        } | ConvertTo-Json -Compress

        $row = [ordered]@{
            CostWithNoReservedInstances        = [double]$costWithoutRI
            CostWithNoReservedInstancesJson    = ''
            FirstUsageDate                     = $firstUsageDate.ToString("yyyy-MM-ddT00:00:00Z")
            InstanceFlexibilityGroup           = $flexGroup
            InstanceFlexibilityRatio           = $flexRatio
            Location                           = $region.Name
            LookBackPeriod                     = $lookBackPeriod
            MeterId                            = $ResourceDef.SkuMeterId
            NetSavings                         = [double]$netSavings
            NetSavingsJson                     = ''
            NormalizedSize                     = $normalizedSize
            ProviderName                       = "Microsoft"
            RecommendedQuantity                = $recommendedQty
            RecommendedQuantityNormalized      = $recommendedQtyNormalized
            ResourceId                         = $ResourceDef.ResourceId
            ResourceName                       = $ResourceDef.ResourceName
            ResourceType                       = $ResourceDef.ResourceType
            Scope                              = $scope
            SKU                                = $skuName
            SkuName                            = $skuName
            SkuProperties                      = ''
            SubAccountId                       = $subAccount.Id
            SubAccountName                     = $subAccount.Name
            SubscriptionId                     = ($subAccount.Id -replace '^/subscriptions/', '')
            Term                               = $term
            TotalCostWithReservedInstances     = [double]$totalCostWithRI
            TotalCostWithReservedInstancesJson = ''
            x_EffectiveCostAfter               = [double]$effectiveCostAfter
            x_EffectiveCostBefore              = [double]$effectiveCostBefore
            x_EffectiveCostSavings             = [double]$effectiveCostSavings
            x_RecommendationCategory           = "Reservation"
            x_RecommendationDate               = $RecommendationDate.ToString("yyyy-MM-ddT00:00:00Z")
            x_RecommendationDescription        = "Purchase $([int]$recommendedQty) $normalizedSize reservation ($term) in $($region.Name) to save `$$([string]::Format('{0:N2}', $netSavings))"
            x_RecommendationDetails            = $recoDetails
            x_RecommendationId                 = [guid]::NewGuid().ToString()
            x_ResourceGroupName                = $ResourceDef.ResourceGroup
            x_SourceName                       = "test-data-generator"
            x_SourceProvider                   = "Microsoft"
            x_SourceType                       = "ReservationRecommendations"
            x_SourceVersion                    = "2023-05-01"
        }

        return [PSCustomObject]$row
    }

    function New-TransactionRow
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param(
            [hashtable]$Identity,
            [hashtable]$Commitment,
            [datetime]$EventDate
        )

        $subAccount = Get-RandomElement -Array $Identity.SubAccounts
        $billingAccount = $subAccount.BillingAccount
        $region = Get-RandomElement -Array @("swedencentral", "eastus", "westeurope", "westus2", "italynorth")

        # Event type distribution: 70% Purchase, 15% Refund, 15% Cancel
        $eventRoll = Get-Random -Maximum 100
        $eventType = if ($eventRoll -lt 70) { "Purchase" } elseif ($eventRoll -lt 85) { "Refund" } else { "Cancel" }

        # Amount: purchases are positive, refunds/cancels are negative
        $amount = Get-RandomDecimal -Min 500 -Max 50000
        if ($eventType -in @("Refund", "Cancel"))
        {
            $amount = - [math]::Abs($amount)
        }

        $billingFrequency = Get-RandomElement -Array @("OneTime", "Recurring")
        $billingMonth = [datetime]::new($EventDate.Year, $EventDate.Month, 1)
        $term = Get-RandomElement -Array @("P1Y", "P3Y")
        $quantity = [double](Get-Random -Minimum 1 -Maximum 10)

        # SKU name from commitment type
        $armSkuName = Get-RandomElement -Array @("Standard_D4s_v5", "Standard_D8s_v5", "Standard_E4s_v5", "Standard_D4as_v5", "Standard_E16s_v5")

        $orderId = $Commitment.SkuOrderId
        $orderName = $Commitment.Name

        # Invoice info
        $invoiceKey = "$($billingAccount.Id)-$($billingMonth.ToString('yyyyMM'))"
        if (-not $Identity.InvoiceIds.ContainsKey($invoiceKey))
        {
            $Identity.InvoiceIds[$invoiceKey] = "INV-$($billingMonth.ToString('yyyyMM'))-$(Get-Random -Minimum 10000 -Maximum 99999)"
        }
        $invoiceId = $Identity.InvoiceIds[$invoiceKey]

        $row = [ordered]@{
            AccountName                = $billingAccount.Name
            AccountOwnerEmail          = "owner@contoso.com"
            Amount                     = [double]$amount
            ArmSkuName                 = $armSkuName
            BillingFrequency           = $billingFrequency
            BillingMonth               = $billingMonth.ToString("yyyy-MM-ddT00:00:00Z")
            BillingProfileId           = (Get-RandomElement -Array $Identity.BillingProfileIds)
            BillingProfileName         = "Billing Profile 1"
            CostCenter                 = "CC-$(Get-Random -Minimum 100 -Maximum 999)"
            Currency                   = "USD"
            CurrentEnrollmentId        = $billingAccount.Id
            DepartmentName             = Get-RandomElement -Array @("Engineering", "Finance", "Operations", "IT")
            Description                = "$armSkuName $($Commitment.Type) $term in $region"
            EventDate                  = $EventDate.ToString("yyyy-MM-ddT00:00:00Z")
            EventType                  = $eventType
            Invoice                    = $invoiceId
            InvoiceId                  = $invoiceId
            InvoiceSectionId           = "IS-$(Get-Random -Minimum 1000 -Maximum 9999)"
            InvoiceSectionName         = "Default Invoice Section"
            MonetaryCommitment         = [double]0
            Overage                    = [double]0
            PurchasingEnrollment       = $billingAccount.Id
            PurchasingSubscriptionGuid = ($subAccount.Id -replace '^/subscriptions/', '')
            PurchasingSubscriptionName = $subAccount.Name
            Quantity                   = $quantity
            Region                     = $region
            ReservationOrderId         = $orderId
            ReservationOrderName       = $orderName
            Term                       = $term
            x_SourceName               = "test-data-generator"
            x_SourceProvider           = "Microsoft"
            x_SourceType               = "ReservationTransactions"
            x_SourceVersion            = "2023-05-01"
        }

        return [PSCustomObject]$row
    }

    # ============================================================================
    # Main Execution
    # ============================================================================

    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "FinOps Hub Multi-Cloud FOCUS Test Data Generator v4.0" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""

    # Determine providers and row distribution
    $providers = if ($ServiceProvider -eq "All")
    {
        @("Azure", "AWS", "GCP", "DataCenter")
    }
    else
    {
        @($ServiceProvider)
    }

    # Row distribution: ~60% Azure, ~20% AWS, ~15% GCP, ~5% DataCenter
    $providerWeights = @{
        "Azure"      = 0.60
        "AWS"        = 0.20
        "GCP"        = 0.15
        "DataCenter" = 0.05
    }

    # If single provider, 100% goes to it
    if ($providers.Count -eq 1)
    {
        $providerWeights = @{ $providers[0] = 1.0 }
    }

    # Calculate total days
    $totalDays = [math]::Max(1, (New-TimeSpan -Start $StartDate -End $EndDate).Days + 1)

    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Cloud Provider(s): $($providers -join ', ')"
    Write-Host "  FOCUS Version: $FocusVersion"
    Write-Host "  Date Range: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd')) ($totalDays days)"
    Write-Host "  Total Row Target: $([string]::Format('{0:N0}', $RowCount))"
    Write-Host "  Total Cost Target: `$$([string]::Format('{0:N0}', $TotalCost)) USD"
    Write-Host "  Output Format: $OutputFormat"
    Write-Host "  Output Path: $OutputPath"
    if ($PSBoundParameters.ContainsKey('Seed')) { Write-Host "  Random Seed: $Seed" }
    Write-Host ""

    # Resolve OutputPath to absolute — Export-Parquet (a .NET cmdlet) uses
    # [IO.Directory]::GetCurrentDirectory() which may differ from PowerShell's $PWD.
    # Converting to absolute here avoids "Could not find a part of the path" errors.
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

    # Create output directory
    if (-not (Test-Path $OutputPath))
    {
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Create output directory'))
        {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
        }
    }

    # === BUDGET SCALE FACTOR ===
    # Estimate average cost per row from config, then compute scale factor to hit target budget.
    # This eliminates the Python post-processing step - costs are scaled inline during generation.
    $estimatedTotalCost = [double]0
    foreach ($provider in $providers)
    {
        $weight = if ($providerWeights.ContainsKey($provider)) { $providerWeights[$provider] } else { 1.0 / $providers.Count }
        $providerRows = [int]($RowCount * $weight)
        $config = $ProviderConfigs[$provider]
        # Weighted average cost from service definitions
        $totalServiceWeight = ($config.Services | ForEach-Object { if ($_.Weight) { $_.Weight } else { 1 } } | Measure-Object -Sum).Sum
        $weightedAvg = [double]0
        foreach ($svc in $config.Services)
        {
            $svcWeight = if ($svc.Weight) { $svc.Weight } else { 1 }
            $svcAvg = ($svc.CostMin + $svc.CostMax) / 2
            $weightedAvg += ($svcAvg * $svcWeight / $totalServiceWeight)
        }
        $estimatedTotalCost += $providerRows * $weightedAvg
    }
    $budgetScaleFactor = if ($estimatedTotalCost -gt 0) { [double]$TotalCost / $estimatedTotalCost } else { 1.0 }

    # Pre-generate identities for each provider
    Write-Host "Pre-generating persistent identities..." -ForegroundColor Yellow
    $providerIdentities = @{}
    foreach ($provider in $providers)
    {
        $providerIdentities[$provider] = New-ProviderIdentity -Provider $provider -Config $ProviderConfigs[$provider]
        $resCount = $providerIdentities[$provider].Resources.Count
        $saCount = $providerIdentities[$provider].SubAccounts.Count
        $baCount = $providerIdentities[$provider].BillingAccounts.Count
        $cdCount = $providerIdentities[$provider].Commitments.Count
        Write-Host "  $provider : $resCount resources, $saCount sub-accounts, $baCount billing accounts, $cdCount commitments" -ForegroundColor Gray
    }
    Write-Host ""

    $totalRows = 0
    $allProviderCosts = @{}
    $allProviderRowCounts = @{}
    $generatedFiles = @()

    # Generate rows for each provider - streaming to CSV to avoid OOM
    foreach ($provider in $providers)
    {
        $weight = if ($providerWeights.ContainsKey($provider)) { $providerWeights[$provider] } else { 1.0 / $providers.Count }
        $providerTotalRows = [math]::Max(1, [int]($RowCount * $weight))
        $dailyRowCount = [math]::Max(1, [int]($providerTotalRows / $totalDays))

        Write-Host "Generating $provider data ($([string]::Format('{0:N0}', $providerTotalRows)) rows, ~$dailyRowCount/day)..." -ForegroundColor Yellow

        $config = $ProviderConfigs[$provider]
        $identity = $providerIdentities[$provider]
        $baseFileName = "focus-$($provider.ToLower())-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd'))"
        $fileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }
        $dataFilePath = Join-Path $OutputPath "$baseFileName.$fileExt"
        $providerCostSum = [double]0
        $headerWritten = $false

        # Always stream daily batches to CSV on disk (never OOMs).
        # If Parquet is requested, convert the CSV to Parquet at the end.
        $csvTempPath = if ($OutputFormat -eq 'Parquet')
        {
            [IO.Path]::ChangeExtension($dataFilePath, '.csv')
        }
        else
        {
            $dataFilePath
        }

        $currentDate = $StartDate
        $rowsGenerated = 0
        $lastPct = -1

        while ($currentDate -le $EndDate -and $rowsGenerated -lt $providerTotalRows)
        {
            # Vary daily count slightly (+/- 10%) for realism
            $variance = [int]($dailyRowCount * 0.1)
            if ($variance -lt 1) { $variance = 1 }
            $todayCount = [math]::Max(1, $dailyRowCount + (Get-Random -Minimum (-$variance) -Maximum ($variance + 1)))

            # Don't exceed target
            if ($rowsGenerated + $todayCount -gt $providerTotalRows)
            {
                $todayCount = $providerTotalRows - $rowsGenerated
            }

            # Generate one day's rows in a small batch
            $dayRows = [System.Collections.Generic.List[PSCustomObject]]::new($todayCount)
            for ($i = 0; $i -lt $todayCount; $i++)
            {
                $row = New-FocusRow -Provider $provider -ChargeDate $currentDate -Config $config -Identity $identity -ScaleFactor $budgetScaleFactor -FocusVer $focusMajorMinor -IncludeCommitments -IncludeHybridBenefit
                $providerCostSum += $row.EffectiveCost
                $dayRows.Add($row)
            }

            # Append daily batch to CSV (stream to disk, free memory)
            if ($PSCmdlet.ShouldProcess($csvTempPath, "Write $todayCount rows"))
            {
                if (-not $headerWritten)
                {
                    $dayRows | Export-Csv -Path $csvTempPath -NoTypeInformation -Encoding UTF8
                    $headerWritten = $true
                }
                else
                {
                    $dayRows | Export-Csv -Path $csvTempPath -NoTypeInformation -Encoding UTF8 -Append
                }
            }
            $dayRows.Clear()
            $dayRows = $null

            $rowsGenerated += $todayCount
            $currentDate = $currentDate.AddDays(1)

            # Progress indicator every 10%
            $pct = [math]::Floor($rowsGenerated / $providerTotalRows * 100)
            if ($pct -ge $lastPct + 10)
            {
                $lastPct = $pct
                Write-Host "  $provider : $pct% ($([string]::Format('{0:N0}', $rowsGenerated)) rows)" -ForegroundColor Gray
            }
        }

        # Convert CSV → Parquet if requested (reads from disk, never holds full dataset in memory at once)
        if ($OutputFormat -eq 'Parquet' -and (Test-Path $csvTempPath))
        {
            if ($PSCmdlet.ShouldProcess($dataFilePath, "Convert $rowsGenerated rows CSV→Parquet"))
            {
                Import-Csv -Path $csvTempPath -Encoding UTF8 | Export-Parquet -FilePath $dataFilePath -Force
                Remove-Item $csvTempPath -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "  $provider : Generated $([string]::Format('{0:N0}', $rowsGenerated)) rows, `$$([string]::Format('{0:N2}', $providerCostSum))" -ForegroundColor Green
        $generatedFiles += $dataFilePath
        $allProviderCosts[$provider] = $providerCostSum
        $allProviderRowCounts[$provider] = $rowsGenerated
        $totalRows += $rowsGenerated

        # Generate manifest.json
        $manifestFilePath = Join-Path $OutputPath "manifest-$($provider.ToLower()).json"
        $fileSize = if (Test-Path $dataFilePath) { (Get-Item $dataFilePath).Length } else { 0 }
        $manifest = @{
            _ftkTestData   = $true
            _generator     = "New-FinOpsTestData"
            _generatedAt   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            exportConfig   = @{
                exportName  = "focus-$($Provider.ToLower())-export"
                resourceId  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg"
                dataVersion = "1.0"
                apiVersion  = "2023-08-01"
                type        = "FocusCost"
                timeFrame   = "Custom"
                granularity = "Daily"
            }
            deliveryConfig = @{
                partitionData         = $true
                dataOverwriteBehavior = "OverwritePreviousReport"
                fileFormat            = $OutputFormat
                compressionMode       = "None"
            }
            blobs          = @(
                @{
                    blobName  = "$baseFileName.$fileExt"
                    byteCount = $fileSize
                }
            )
            runInfo        = @{
                executionType = "Scheduled"
                submittedTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                runId         = [guid]::NewGuid().ToString()
                startDate     = $StartDate.ToString("yyyy-MM-ddT00:00:00Z")
                endDate       = $EndDate.ToString("yyyy-MM-ddT00:00:00Z")
            }
        } | ConvertTo-Json -Depth 5

        if ($PSCmdlet.ShouldProcess($manifestFilePath, 'Create manifest file'))
        {
            $manifest | Out-File -FilePath $manifestFilePath -Encoding UTF8
            Write-Host "  Saved manifest: $manifestFilePath" -ForegroundColor Gray
            $generatedFiles += $manifestFilePath
        }

        # Force GC between providers to reclaim memory
        [System.GC]::Collect()
    }

    # ============================================================================
    # Generate Additional FOCUS Datasets (Azure-only)
    # ============================================================================
    # These datasets are Azure Cost Management-specific exports:
    # - Prices (PriceSheet)
    # - CommitmentDiscountUsage (ReservationDetails)
    # - Recommendations (ReservationRecommendations)
    # - Transactions (ReservationTransactions)
    # ============================================================================

    $additionalDatasetFiles = @{}

    if ($providers -contains "Azure")
    {
        $azureConfig = $ProviderConfigs["Azure"]
        $azureIdentity = $providerIdentities["Azure"]

        # --- Prices Dataset ---
        Write-Host ""
        Write-Host "Generating Prices dataset (Azure price sheet)..." -ForegroundColor Yellow

        $priceRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        # Generate price rows for each resource in the identity pool × price types
        $priceTypes = @(
            @{ Type = "Consumption"; Term = "" },
            @{ Type = "ReservedInstance"; Term = "P1Y" },
            @{ Type = "ReservedInstance"; Term = "P3Y" },
            @{ Type = "SavingsPlan"; Term = "P1Y" },
            @{ Type = "SavingsPlan"; Term = "P3Y" }
        )

        # Sample a subset of resources for price rows (one price per resource per type)
        $priceResourceSample = $azureIdentity.Resources | Get-Random -Count ([math]::Min(100, $azureIdentity.Resources.Count))
        foreach ($res in $priceResourceSample)
        {
            foreach ($pt in $priceTypes)
            {
                # Consumption rows for all, RI/SP only for eligible services
                if ($pt.Type -ne "Consumption" -and $res.Service.Category -notin @("Compute", "Databases"))
                {
                    continue
                }
                $priceRow = New-PriceRow -Config $azureConfig -Identity $azureIdentity -ServiceDef $res.Service -ResourceDef $res -PriceType $pt.Type -Term $pt.Term
                $priceRows.Add($priceRow)
            }
        }

        $priceFileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }
        $priceFileName = "prices-azure-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd')).$priceFileExt"
        $priceFilePath = Join-Path $OutputPath $priceFileName

        if ($OutputFormat -eq 'Parquet' -and $priceRows.Count -gt 0)
        {
            # Handle nulls for PSParquet
            $numericCols = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
                    'BasePrice', 'IncludedQuantity', 'MarketPrice', 'TierMinimumUnits', 'UnitPrice'
                ))
            $propNames = $priceRows[0].PSObject.Properties.Name
            foreach ($r in $priceRows)
            {
                foreach ($pn in $propNames)
                {
                    if ($null -eq $r.$pn)
                    {
                        $r.$pn = if ($numericCols.Contains($pn)) { [double]0 } else { '' }
                    }
                }
            }
            $priceRows.ToArray() | Export-Parquet -FilePath $priceFilePath -Force
        }
        elseif ($priceRows.Count -gt 0)
        {
            $priceRows | Export-Csv -Path $priceFilePath -NoTypeInformation -Encoding UTF8
        }

        Write-Host "  Prices: $($priceRows.Count) rows saved to $priceFileName" -ForegroundColor Green
        $generatedFiles += $priceFilePath
        $additionalDatasetFiles["Prices"] = $priceFilePath
        $priceRows.Clear(); $priceRows = $null
        [System.GC]::Collect()

        # --- CommitmentDiscountUsage Dataset ---
        Write-Host "Generating CommitmentDiscountUsage dataset (reservation details)..." -ForegroundColor Yellow

        $cduRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        if ($azureIdentity.Commitments.Count -gt 0)
        {
            # Only Reservation commitments have usage details
            $reservationCommitments = $azureIdentity.Commitments | Where-Object { $_.Type -eq "Reservation" }
            if ($reservationCommitments.Count -gt 0)
            {
                # For each day in the date range, generate usage for each reservation
                $currentDate = $StartDate
                while ($currentDate -le $EndDate)
                {
                    foreach ($commitment in $reservationCommitments)
                    {
                        # Each reservation may cover 1-3 resources per day
                        $coveredCount = Get-Random -Minimum 1 -Maximum 4
                        $coveredResources = $azureIdentity.Resources | Where-Object { $_.Service.Category -in @("Compute", "Databases") } | Get-Random -Count ([math]::Min($coveredCount, ($azureIdentity.Resources | Where-Object { $_.Service.Category -in @("Compute", "Databases") }).Count))
                        foreach ($res in $coveredResources)
                        {
                            $cduRow = New-CommitmentDiscountUsageRow -Commitment $commitment -UsageDate $currentDate -ResourceDef $res
                            $cduRows.Add($cduRow)
                        }
                    }
                    $currentDate = $currentDate.AddDays(1)
                }
            }
        }

        $cduFileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }
        $cduFileName = "commitmentdiscountusage-azure-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd')).$cduFileExt"
        $cduFilePath = Join-Path $OutputPath $cduFileName

        if ($OutputFormat -eq 'Parquet' -and $cduRows.Count -gt 0)
        {
            $numericCols = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
                    'InstanceFlexibilityRatio', 'ReservedHours', 'TotalReservedQuantity', 'UsedHours'
                ))
            $propNames = $cduRows[0].PSObject.Properties.Name
            foreach ($r in $cduRows)
            {
                foreach ($pn in $propNames)
                {
                    if ($null -eq $r.$pn)
                    {
                        $r.$pn = if ($numericCols.Contains($pn)) { [double]0 } else { '' }
                    }
                }
            }
            $cduRows.ToArray() | Export-Parquet -FilePath $cduFilePath -Force
        }
        elseif ($cduRows.Count -gt 0)
        {
            $cduRows | Export-Csv -Path $cduFilePath -NoTypeInformation -Encoding UTF8
        }

        Write-Host "  CommitmentDiscountUsage: $($cduRows.Count) rows saved to $cduFileName" -ForegroundColor Green
        $generatedFiles += $cduFilePath
        $additionalDatasetFiles["CommitmentDiscountUsage"] = $cduFilePath
        $cduRows.Clear(); $cduRows = $null
        [System.GC]::Collect()

        # --- Recommendations Dataset ---
        Write-Host "Generating Recommendations dataset (reservation recommendations)..." -ForegroundColor Yellow

        $recoRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        # Generate recommendations for compute/database resources eligible for reservations
        $eligibleResources = $azureIdentity.Resources | Where-Object { $_.Service.Category -in @("Compute", "Databases") }
        $recoResourceSample = $eligibleResources | Get-Random -Count ([math]::Min(50, $eligibleResources.Count))

        foreach ($res in $recoResourceSample)
        {
            # 1-3 recommendations per resource (different lookback/term combos)
            $recoCount = Get-Random -Minimum 1 -Maximum 4
            for ($i = 0; $i -lt $recoCount; $i++)
            {
                $recoDate = $EndDate.AddDays( - (Get-Random -Minimum 0 -Maximum 30))
                $recoRow = New-RecommendationRow -ResourceDef $res -RecommendationDate $recoDate
                $recoRows.Add($recoRow)
            }
        }

        $recoFileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }
        $recoFileName = "recommendations-azure-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd')).$recoFileExt"
        $recoFilePath = Join-Path $OutputPath $recoFileName

        if ($OutputFormat -eq 'Parquet' -and $recoRows.Count -gt 0)
        {
            $numericCols = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
                    'CostWithNoReservedInstances', 'InstanceFlexibilityRatio', 'NetSavings',
                    'RecommendedQuantity', 'RecommendedQuantityNormalized', 'TotalCostWithReservedInstances',
                    'x_EffectiveCostAfter', 'x_EffectiveCostBefore', 'x_EffectiveCostSavings'
                ))
            $propNames = $recoRows[0].PSObject.Properties.Name
            foreach ($r in $recoRows)
            {
                foreach ($pn in $propNames)
                {
                    if ($null -eq $r.$pn)
                    {
                        $r.$pn = if ($numericCols.Contains($pn)) { [double]0 } else { '' }
                    }
                }
            }
            $recoRows.ToArray() | Export-Parquet -FilePath $recoFilePath -Force
        }
        elseif ($recoRows.Count -gt 0)
        {
            $recoRows | Export-Csv -Path $recoFilePath -NoTypeInformation -Encoding UTF8
        }

        Write-Host "  Recommendations: $($recoRows.Count) rows saved to $recoFileName" -ForegroundColor Green
        $generatedFiles += $recoFilePath
        $additionalDatasetFiles["Recommendations"] = $recoFilePath
        $recoRows.Clear(); $recoRows = $null
        [System.GC]::Collect()

        # --- Transactions Dataset ---
        Write-Host "Generating Transactions dataset (reservation transactions)..." -ForegroundColor Yellow

        $transRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        if ($azureIdentity.Commitments.Count -gt 0)
        {
            foreach ($commitment in $azureIdentity.Commitments)
            {
                # 1-4 transactions per commitment over the date range
                $transCount = Get-Random -Minimum 1 -Maximum 5
                for ($i = 0; $i -lt $transCount; $i++)
                {
                    $eventDate = $StartDate.AddDays((Get-Random -Minimum 0 -Maximum ([math]::Max(1, $totalDays))))
                    if ($eventDate -gt $EndDate) { $eventDate = $EndDate }
                    $transRow = New-TransactionRow -Identity $azureIdentity -Commitment $commitment -EventDate $eventDate
                    $transRows.Add($transRow)
                }
            }
        }

        $transFileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }
        $transFileName = "transactions-azure-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd')).$transFileExt"
        $transFilePath = Join-Path $OutputPath $transFileName

        if ($OutputFormat -eq 'Parquet' -and $transRows.Count -gt 0)
        {
            $numericCols = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
                    'Amount', 'MonetaryCommitment', 'Overage', 'Quantity'
                ))
            $propNames = $transRows[0].PSObject.Properties.Name
            foreach ($r in $transRows)
            {
                foreach ($pn in $propNames)
                {
                    if ($null -eq $r.$pn)
                    {
                        $r.$pn = if ($numericCols.Contains($pn)) { [double]0 } else { '' }
                    }
                }
            }
            $transRows.ToArray() | Export-Parquet -FilePath $transFilePath -Force
        }
        elseif ($transRows.Count -gt 0)
        {
            $transRows | Export-Csv -Path $transFilePath -NoTypeInformation -Encoding UTF8
        }

        Write-Host "  Transactions: $($transRows.Count) rows saved to $transFileName" -ForegroundColor Green
        $generatedFiles += $transFilePath
        $additionalDatasetFiles["Transactions"] = $transFilePath
        $transRows.Clear(); $transRows = $null

        [System.GC]::Collect()
        Write-Host ""
    }

    # ============================================================================
    # Summary
    # ============================================================================

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "Generation Complete!" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Total Rows Generated: $([string]::Format('{0:N0}', $totalRows))"
    $actualTotal = ($allProviderCosts.Values | Measure-Object -Sum).Sum
    Write-Host "  Total Cost: `$$([string]::Format('{0:N2}', $actualTotal)) USD"
    Write-Host "  FOCUS Version: $FocusVersion"
    Write-Host "  Output Format: $OutputFormat"
    Write-Host "  Files Created: $($generatedFiles.Count)"
    Write-Host ""
    Write-Host "Provider Breakdown:" -ForegroundColor Yellow
    foreach ($provider in $providers)
    {
        $providerCost = $allProviderCosts[$provider]
        $providerRowCount = $allProviderRowCounts[$provider]
        Write-Host "  $provider : $([string]::Format('{0:N0}', $providerRowCount)) rows | `$$([string]::Format('{0:N2}', $providerCost))"
    }
    Write-Host ""
    Write-Host "Generated Files:" -ForegroundColor Yellow
    foreach ($file in $generatedFiles)
    {
        if (Test-Path $file)
        {
            $size = (Get-Item $file).Length / 1MB
            Write-Host "  - $file ($([math]::Round($size, 2)) MB)"
        }
    }

    Write-Host ""
    Write-Host "FOCUS Column Coverage (v$FocusVersion):" -ForegroundColor Cyan
    Write-Host "  PricingCategory: Standard, Dynamic, Committed"
    Write-Host "  CommitmentDiscountStatus: Used, Unused (with SkuOrderId/SkuTerm linkage)"
    Write-Host "  CommitmentDiscountType: Reservation, Savings Plan (+ Purchase rows)"
    if ($focusMajorMinor -ge [version]'1.1') { Write-Host "  CommitmentDiscountQuantity/Unit: Included (v1.1+)" }
    if ($focusMajorMinor -ge [version]'1.2') { Write-Host "  BillingAccountType, SubAccountType, InvoiceId: Included (v1.2+)" }
    if ($focusMajorMinor -ge [version]'1.3') { Write-Host "  HostProviderName, ServiceProviderName: Included (v1.3+)" }
    if ($focusMajorMinor -ge [version]'1.3') { Write-Host "  ContractApplied: JSON for committed-discount rows (v1.3+)" }
    if ($focusMajorMinor -ge [version]'1.3') { Write-Host "  Allocated* columns: ~10% of AKS/EKS/GKE rows with split cost data (v1.3+)" }
    Write-Host "  Azure Hybrid Benefit: x_SkuLicenseStatus Enabled/Not Enabled"
    Write-Host "  CPU Architecture: Intel/AMD/Arm64 patterns in x_SkuMeterName"
    Write-Host "  Tag coverage: ~80% tagged, ~20% untagged (maturity scorecard)"
    Write-Host "  Data quality anomalies: ~2% rows (ChargeClass=Correction, x_SourceChanges set)"
    Write-Host "  Note: All columns emitted for every version (empty/null for non-applicable) to maintain"
    Write-Host "         a consistent Parquet schema. Contract Commitment dataset not included."
    Write-Host ""
    Write-Host "Additional FOCUS Datasets (Azure-only):" -ForegroundColor Cyan
    if ($additionalDatasetFiles.Count -gt 0)
    {
        foreach ($ds in $additionalDatasetFiles.Keys)
        {
            $dsPath = $additionalDatasetFiles[$ds]
            if (Test-Path $dsPath)
            {
                $dsSize = [math]::Round((Get-Item $dsPath).Length / 1MB, 2)
                Write-Host "  $ds : $dsSize MB"
            }
        }
    }
    else
    {
        Write-Host "  (Azure not in provider list — additional datasets skipped)"
    }
    Write-Host ""

    # ============================================================================
    # Upload to Azure Storage
    # ============================================================================

    if ($StorageAccountName)
    {
        Write-Host ""
        Write-Host ("=" * 70) -ForegroundColor Cyan
        Write-Host "Uploading to Azure Storage..." -ForegroundColor Yellow
        Write-Host ("=" * 70) -ForegroundColor Cyan

        # Authentication: use Azure AD (connected account)
        $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

        # Start ADF triggers BEFORE uploading data so Event Grid events are captured
        if ($StartTriggers -and $AdfName -and $ResourceGroupName)
        {
            Write-Host ""
            Write-Host "Ensuring ADF Triggers are running (BEFORE upload)..." -ForegroundColor Yellow

            $triggers = $AdfTriggerNames
            foreach ($trigger in $triggers)
            {
                if ($PSCmdlet.ShouldProcess($trigger, "Start ADF trigger"))
                {
                    $triggerObj = Get-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $AdfName -Name $trigger -ErrorAction SilentlyContinue
                    $state = $triggerObj.RuntimeState
                    if ($state -eq "Started")
                    {
                        Write-Host "  $trigger already running" -ForegroundColor Gray
                    }
                    else
                    {
                        Write-Host "  Starting $trigger..." -ForegroundColor Cyan
                        Start-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $AdfName -Name $trigger -Force | Out-Null
                        Write-Host "  $trigger started" -ForegroundColor Green
                    }
                }
            }

            Write-Host "  Waiting 5 seconds for triggers to become active..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
            Write-Host ""
        }

        $uploadedCount = 0
        $runId = [guid]::NewGuid().ToString()
        $exportTime = (Get-Date).ToString("yyyyMMddHHmm")

        foreach ($provider in $providers)
        {
            $providerLower = $provider.ToLower()
            $baseFileName = "focus-$providerLower-$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd'))"
            $uploadFileExt = if ($OutputFormat -eq 'Parquet') { 'parquet' } else { 'csv' }

            $dataFile = "$baseFileName.$uploadFileExt"
            $dataFilePath = Join-Path $OutputPath $dataFile

            if (-not (Test-Path $dataFilePath))
            {
                Write-Host "  Warning: $dataFilePath not found, skipping $provider" -ForegroundColor Yellow
                continue
            }

            $fileSize = (Get-Item $dataFilePath).Length

            if ($providerLower -eq "azure")
            {
                # Azure: msexports with Cost Management folder structure
                $container = "msexports"
                $scopeId = "subscriptions/00000000-0000-0000-0000-000000000000"
                $exportName = "focus-cost-export"
                $dateRange = "$($StartDate.ToString('yyyyMMdd'))-$($EndDate.ToString('yyyyMMdd'))"
                $blobFolder = "$scopeId/$exportName/$dateRange/$exportTime/$runId"
                $blobPath = "$blobFolder/$dataFile"
                $manifestBlobPath = "$blobFolder/manifest.json"

                $manifest = @{
                    _ftkTestData    = $true
                    _generator      = "New-FinOpsTestData"
                    _generatedAt    = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    manifestVersion = "2024-04-01"
                    byteCount       = $fileSize
                    blobCount       = 1
                    dataRowCount    = $allProviderRowCounts[$provider]
                    exportConfig    = @{
                        exportName  = $exportName
                        resourceId  = "/$scopeId/providers/Microsoft.CostManagement/exports/$exportName"
                        dataVersion = "1.0r2"
                        apiVersion  = "2023-07-01-preview"
                        type        = "FocusCost"
                        timeFrame   = "Custom"
                        granularity = "Daily"
                    }
                    deliveryConfig  = @{
                        partitionData         = $true
                        dataOverwriteBehavior = "OverwritePreviousReport"
                        fileFormat            = "Parquet"
                        compressionMode       = "None"
                        containerUri          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
                        rootFolderPath        = ""
                    }
                    runInfo         = @{
                        executionType = "Scheduled"
                        submittedTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
                        runId         = $runId
                        startDate     = $StartDate.ToString("yyyy-MM-ddT00:00:00")
                        endDate       = $EndDate.ToString("yyyy-MM-ddT00:00:00")
                    }
                    blobs           = @(
                        @{
                            blobName     = $blobPath
                            byteCount    = $fileSize
                            dataRowCount = $allProviderRowCounts[$provider]
                        }
                    )
                } | ConvertTo-Json -Depth 5

                $manifestFilePath = Join-Path $OutputPath "manifest-$providerLower.json"
                $manifest | Out-File -FilePath $manifestFilePath -Encoding UTF8

                if ($PSCmdlet.ShouldProcess("$container/$blobPath", "Upload to Azure Storage"))
                {
                    Write-Host "  Uploading $provider to msexports container..." -ForegroundColor Cyan
                    Write-Host "    Step 1: Upload data file (before manifest to ensure ADF finds it)..." -ForegroundColor Gray
                    Set-AzStorageBlobContent -Container $container -File $dataFilePath -Blob $blobPath -Context $storageContext -Force | Out-Null
                    Write-Host "    Step 2: Upload manifest.json (triggers ADF pipeline)..." -ForegroundColor Gray
                    Set-AzStorageBlobContent -Container $container -File $manifestFilePath -Blob $manifestBlobPath -Context $storageContext -Force | Out-Null
                }

            }
            else
            {
                # AWS/GCP/DataCenter: ingestion container
                $container = "ingestion"
                $scopePath = "$providerLower/test-account"
                $ingestionId = (Get-Date).ToString("yyyyMMddHHmmss")
                $blobFolder = "Costs/$($EndDate.ToString('yyyy'))/$($EndDate.ToString('MM'))/$scopePath"
                $blobPath = "$blobFolder/${ingestionId}__$dataFile"
                $manifestBlobPath = "$blobFolder/manifest.json"

                $manifest = @{
                    _ftkTestData = $true
                    _generator   = "New-FinOpsTestData"
                    _generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    note         = "Trigger file for ADX ingestion"
                    provider     = $providerLower
                    timestamp    = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                } | ConvertTo-Json -Depth 3

                $manifestFilePath = Join-Path $OutputPath "manifest-$providerLower.json"
                $manifest | Out-File -FilePath $manifestFilePath -Encoding UTF8

                if ($PSCmdlet.ShouldProcess("$container/$blobPath", "Upload to Azure Storage"))
                {
                    Write-Host "  Uploading $provider to ingestion container..." -ForegroundColor Cyan
                    Set-AzStorageBlobContent -Container $container -File $dataFilePath -Blob $blobPath -Context $storageContext -Force | Out-Null
                    Set-AzStorageBlobContent -Container $container -File $manifestFilePath -Blob $manifestBlobPath -Context $storageContext -Force | Out-Null
                }
            }

            Write-Host "    Uploaded: $blobPath" -ForegroundColor Green
            Write-Host "    Uploaded: $manifestBlobPath" -ForegroundColor Green
            $uploadedCount++
        }

        Write-Host ""
        Write-Host "Upload Complete! $uploadedCount providers uploaded." -ForegroundColor Green

        # Upload additional FOCUS datasets (Prices, CommitmentDiscountUsage, Recommendations, Transactions)
        if ($additionalDatasetFiles.Count -gt 0)
        {
            Write-Host ""
            Write-Host "Uploading additional FOCUS datasets to ingestion container..." -ForegroundColor Yellow

            $container = "ingestion"
            $ingestionId = (Get-Date).ToString("yyyyMMddHHmmss")

            foreach ($datasetName in $additionalDatasetFiles.Keys)
            {
                $datasetFilePath = $additionalDatasetFiles[$datasetName]
                if (-not (Test-Path $datasetFilePath))
                {
                    Write-Host "  Warning: $datasetFilePath not found, skipping $datasetName" -ForegroundColor Yellow
                    continue
                }

                $datasetFileName = [System.IO.Path]::GetFileName($datasetFilePath)
                $scopePath = "azure/test-account"
                $blobFolder = "$datasetName/$($EndDate.ToString('yyyy'))/$($EndDate.ToString('MM'))/$scopePath"
                $blobPath = "$blobFolder/${ingestionId}__$datasetFileName"
                $manifestBlobPath = "$blobFolder/manifest.json"

                # Create a simple manifest for ingestion trigger
                $manifest = @{
                    _ftkTestData = $true
                    _generator   = "New-FinOpsTestData"
                    _generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    note         = "Trigger file for ADX ingestion - $datasetName"
                    provider     = "azure"
                    dataset      = $datasetName
                    timestamp    = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                } | ConvertTo-Json -Depth 3

                $manifestFilePath = Join-Path $OutputPath "manifest-$($datasetName.ToLower()).json"
                $manifest | Out-File -FilePath $manifestFilePath -Encoding UTF8

                if ($PSCmdlet.ShouldProcess("$container/$blobPath", "Upload $datasetName to Azure Storage"))
                {
                    Write-Host "  Uploading $datasetName..." -ForegroundColor Cyan
                    Set-AzStorageBlobContent -Container $container -File $datasetFilePath -Blob $blobPath -Context $storageContext -Force | Out-Null
                    Set-AzStorageBlobContent -Container $container -File $manifestFilePath -Blob $manifestBlobPath -Context $storageContext -Force | Out-Null
                    Write-Host "    Uploaded: $blobPath" -ForegroundColor Green
                    Write-Host "    Uploaded: $manifestBlobPath" -ForegroundColor Green
                }
            }

            Write-Host ""
            Write-Host "Additional datasets uploaded!" -ForegroundColor Green
        }

        # Verify ADF pipeline execution
        if ($StartTriggers -and $AdfName -and $ResourceGroupName)
        {
            Write-Host ""
            Write-Host "Verifying ADF Pipeline Execution..." -ForegroundColor Yellow

            Write-Host "  Waiting 15 seconds for blob events to propagate..." -ForegroundColor Gray
            Start-Sleep -Seconds 15

            $now = (Get-Date).ToUniversalTime()
            $checkFrom = $now.AddMinutes(-5)
            $checkTo = $now.AddMinutes(5)

            $pipelineRuns = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $ResourceGroupName -DataFactoryName $AdfName -LastUpdatedAfter $checkFrom -LastUpdatedBefore $checkTo -ErrorAction SilentlyContinue

            if ($pipelineRuns -and $pipelineRuns.Count -gt 0)
            {
                Write-Host "  ADF pipelines triggered successfully!" -ForegroundColor Green
                foreach ($run in $pipelineRuns)
                {
                    Write-Host "    $($run.PipelineName) | $($run.Status)" -ForegroundColor Gray
                }
            }
            else
            {
                Write-Host "  No pipeline runs detected yet. Manifests may trigger shortly." -ForegroundColor Yellow
            }
        }
        elseif ($StartTriggers)
        {
            Write-Host ""
            Write-Host "Warning: -StartTriggers requires -AdfName and -ResourceGroupName" -ForegroundColor Yellow
        }
    }
    else
    {
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Run with -StorageAccountName <name> to upload automatically"
        Write-Host "  2. Or manually upload:"
        Write-Host "     - Azure data to msexports/{scope}/{export-name}/{date-range}/{time}/{guid}/"
        Write-Host "     - AWS/GCP/DC data to ingestion/Costs/{yyyy}/{mm}/{provider}/{account}/"
        Write-Host "     - Prices to ingestion/Prices/{yyyy}/{mm}/azure/test-account/"
        Write-Host "     - CommitmentDiscountUsage to ingestion/CommitmentDiscountUsage/{yyyy}/{mm}/azure/test-account/"
        Write-Host "     - Recommendations to ingestion/Recommendations/{yyyy}/{mm}/azure/test-account/"
        Write-Host "     - Transactions to ingestion/Transactions/{yyyy}/{mm}/azure/test-account/"
        Write-Host "  3. Ensure ADF triggers are running (use -StartTriggers to restart them)"
    }

    Write-Host ""
}
