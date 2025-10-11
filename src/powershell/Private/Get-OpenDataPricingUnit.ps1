# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-OpenDataPricingUnit
{
    param()
    return [PSCustomObject]@(
        [PSCustomObject]@{ UnitOfMeasure = '1'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 '; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 /Day'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 /Minute'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Minute'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 /Month'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 /Year'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 1 Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 API Calls'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Agents'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Agents'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Annual Domain'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Domains/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Annual Domains'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Domains/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Annual Subscriptions'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Subscriptions/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Border Routers'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Routers'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Certificate'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Certificates'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Concurrent DVC'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Configurations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Connection'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Connections'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Content Hours'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Count'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Count'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Cubic Meter/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Cubic Meters/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily App'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Apps/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Connection'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Connections/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Connections'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Connections/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Pack'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Packs/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Reserved Unit'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Reserved Units'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Unit'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily Units'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Daily User'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Users/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Database Unit'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Database Units (DU)'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Day'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Days'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Device'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Devices'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Devices'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Devices'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Executions'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Executions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB Second'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB/Day'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB/Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB/hora'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GB/?'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Gb'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GiB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GiB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB Minute'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GiB Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB Second'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GiB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB/Day'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GiB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB/Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 GiB/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'GiB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Hourly Connection'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Connections/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Hourly Unit'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Hourly Units'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Hours'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 IOPS/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'IOPS/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Key'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Keys'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Key Use'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Keys'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 MB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'MB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 MB/Day'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'MB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 MB/Month'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'MB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Maps'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Maps'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Messaging Unit'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Million'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Million'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Minute'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Named Users'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Node'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Nodes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Nodes'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Nodes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 PB Second'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'PB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 PB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'PB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 PiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'PiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Pipeline'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Pipelines'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Plan'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Plans'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Plans'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Plans'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Policies'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Policies'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Resource'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Resources'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Rotation'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Rotation'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Second'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Sites'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Sites'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Subscription'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Subscriptions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Subscriptions'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Subscriptions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'TB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB Second'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB/Day'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TB/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'TB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TiB'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TiB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TiB Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TiB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 TiB/Month'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'TiB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Unit'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Units'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 User'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Users'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 VM'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Virtual Machines'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Virtual Machine'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Virtual Machines'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Website'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Websites'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 Zones'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Zones'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 day'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 hora'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 hour'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 por mes'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 user'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1 ??'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/10 Days'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/10 Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/3 Months'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/3 Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/6 Months'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/6 Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Day'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Hour'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Minute'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/Minute'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Second'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/Second'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/Year'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1/??'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10'; AccountTypes = 'MCA, EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 '; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 /Day'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 /Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Activities'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Activities'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 DB Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'DB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 DBU Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'DBU Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Database Unit'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Database Units (DU)'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Days'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Devices'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Devices'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 GB'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 GB/Day'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'GB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 GB/Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 GiB'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'GiB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 GiB/Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'GiB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Hourly Units'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Instance Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Months'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 PB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'PB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 PB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'PB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 PiB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'PiB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 PiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'PiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Pipelines'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Pipelines'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Rotations'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Rotations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Service Endpoints'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Endpoints'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TB'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TB Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TB/Day'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TB/Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TiB'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TiB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TiB Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TiB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 TiB/Month'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'TiB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Unit'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Unit Hours'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Unit Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 Units'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10 day'; AccountTypes = 'EA'; PricingBlockSize = 10; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100'; AccountTypes = 'MCA, EA'; PricingBlockSize = 100; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 '; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 /Day'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 /Minute'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units/Minute'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 /Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 API Calls'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Authentications'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Authentications'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Connections'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Core Hours'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Core Hrs'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Days'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GB'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GB Seconds'; AccountTypes = 'MCA'; PricingBlockSize = 100; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GB/Day'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GB/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GB/Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GiB'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GiB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 GiB/Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'GiB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Hour'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Hourly Units'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Hours'; AccountTypes = 'MCA, EA'; PricingBlockSize = 100; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 IOPS/Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'IOPS/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 MB'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'MB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 MB/Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'MB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Mbps'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Mbps'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Months'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Seconds'; AccountTypes = 'MCA, EA'; PricingBlockSize = 100; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 TB'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'TB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 TB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'TB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 TB/Month'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'TB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 TiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'TiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Unit'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Units'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100 Users'; AccountTypes = 'EA'; PricingBlockSize = 100; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100/Hour'; AccountTypes = 'MCA'; PricingBlockSize = 100; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100/Month'; AccountTypes = 'MCA'; PricingBlockSize = 100; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 '; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 /Day'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 /Minute'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Minute'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 /Year'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Year'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 APIs'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'APIs'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Activity Runs'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Runs'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Checks'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Checks'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Executions'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Executions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 GB'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 GB Hours'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'GB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 GB/Month'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Hours'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 IOPS/Month'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'IOPS/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Keys'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Keys'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Licenses'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Licenses'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 MAUS'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Users/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 MAUs'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Users/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 MB/Month'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'MB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Months'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Months'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Relay Hours'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Relay Hrs'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Renders'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Renders'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 TB'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'TB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 1000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 '; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 /Day'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 1,000s'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Transactions in Thousands'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Actions'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Actions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Authentications'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Authentications'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Executions'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Executions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Faces'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Faces'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 GB'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 GB Hours'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'GB Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 GB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'GB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 GB/Month'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 GiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'GiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Hours'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Operations'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Operations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Predictions'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Predictions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Users'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Users'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000 Virtual User Minutes'; AccountTypes = 'EA'; PricingBlockSize = 10000; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 '; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 /Day'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 Executions'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Executions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 GB'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 GB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 GB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'GB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 GiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'GiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 Hours'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 Seconds'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 100000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 '; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Data Points'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Data Points'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 GB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Messages'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Messages'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Operations'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Operations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Pushes'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Pushes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Requests'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Seconds'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 1000000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 '; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 GB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 Operations'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Operations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 Pushes'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Pushes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 Queries'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Queries'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 Seconds'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 10000000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 '; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 /Day'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 /Month'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 Events'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Events'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 Operation Units'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 Operations'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Operations'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 Pushes'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Pushes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 100000000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000000'; AccountTypes = 'EA'; PricingBlockSize = 1000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1000000000 '; AccountTypes = 'EA'; PricingBlockSize = 1000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000000'; AccountTypes = 'EA'; PricingBlockSize = 10000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000000000 '; AccountTypes = 'EA'; PricingBlockSize = 10000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000000'; AccountTypes = 'EA'; PricingBlockSize = 100000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100000000000 '; AccountTypes = 'EA'; PricingBlockSize = 100000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10000s'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '100K'; AccountTypes = 'MCA'; PricingBlockSize = 100000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1024 GB'; AccountTypes = 'EA'; PricingBlockSize = 1024; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '102400 TiB/Hour'; AccountTypes = 'EA'; PricingBlockSize = 102400; DistinctUnits = 'TiB/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10K'; AccountTypes = 'MCA, EA'; PricingBlockSize = 10000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10K Transactions'; AccountTypes = 'MCA'; PricingBlockSize = 10000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10K/Hour'; AccountTypes = 'MCA'; PricingBlockSize = 10000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10K/Month'; AccountTypes = 'MCA, EA'; PricingBlockSize = 10000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '10M'; AccountTypes = 'MCA, EA'; PricingBlockSize = 10000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '128 MB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 128; DistinctUnits = 'MB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '150 Hours'; AccountTypes = 'EA'; PricingBlockSize = 150; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1B'; AccountTypes = 'MCA'; PricingBlockSize = 1000000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1K'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1K/Day'; AccountTypes = 'MCA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1K/Hour'; AccountTypes = 'MCA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1K/Month'; AccountTypes = 'MCA'; PricingBlockSize = 1000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1M'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1M/Month'; AccountTypes = 'MCA'; PricingBlockSize = 1000000; DistinctUnits = 'Units/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '1?GB/mes'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2'; AccountTypes = 'EA'; PricingBlockSize = 2; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2 '; AccountTypes = 'EA'; PricingBlockSize = 2; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2 Hosted Zones'; AccountTypes = 'EA'; PricingBlockSize = 2; DistinctUnits = 'Zones'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '20 GB/Month'; AccountTypes = 'EA'; PricingBlockSize = 20; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200'; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200 '; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200 /Hour'; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'Units/Hour'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200 GB'; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200 Hours'; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200 minutes'; AccountTypes = 'EA'; PricingBlockSize = 200; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2000 Hours'; AccountTypes = 'EA'; PricingBlockSize = 2000; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200000'; AccountTypes = 'EA'; PricingBlockSize = 200000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200000 '; AccountTypes = 'EA'; PricingBlockSize = 200000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '200000 Transactions'; AccountTypes = 'EA'; PricingBlockSize = 200000; DistinctUnits = 'Transactions'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2000000'; AccountTypes = 'EA'; PricingBlockSize = 2000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2000000 '; AccountTypes = 'EA'; PricingBlockSize = 2000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '25000 '; AccountTypes = 'EA'; PricingBlockSize = 25000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '250000'; AccountTypes = 'EA'; PricingBlockSize = 250000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '250000 '; AccountTypes = 'EA'; PricingBlockSize = 250000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '2500000 '; AccountTypes = 'EA'; PricingBlockSize = 2500000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '25K'; AccountTypes = 'MCA'; PricingBlockSize = 25000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '30 /Day'; AccountTypes = 'EA'; PricingBlockSize = 30; DistinctUnits = 'Units/Day'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '30 Days'; AccountTypes = 'EA'; PricingBlockSize = 30; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '31 Connections'; AccountTypes = 'EA'; PricingBlockSize = 31; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5 Connections'; AccountTypes = 'EA'; PricingBlockSize = 5; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5 GB'; AccountTypes = 'MCA, EA'; PricingBlockSize = 5; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5 TB'; AccountTypes = 'EA'; PricingBlockSize = 5; DistinctUnits = 'TB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '50 Hours'; AccountTypes = 'EA'; PricingBlockSize = 50; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500'; AccountTypes = 'EA'; PricingBlockSize = 500; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500 '; AccountTypes = 'EA'; PricingBlockSize = 500; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500 Hours'; AccountTypes = 'EA'; PricingBlockSize = 500; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500 Minute'; AccountTypes = 'EA'; PricingBlockSize = 500; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 500; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '50000'; AccountTypes = 'EA'; PricingBlockSize = 50000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '50000 '; AccountTypes = 'EA'; PricingBlockSize = 50000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '50000 GB Seconds'; AccountTypes = 'EA'; PricingBlockSize = 50000; DistinctUnits = 'GB Seconds'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '500000 Requests'; AccountTypes = 'EA'; PricingBlockSize = 500000; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5000000'; AccountTypes = 'EA'; PricingBlockSize = 5000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5000000 '; AccountTypes = 'EA'; PricingBlockSize = 5000000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5000000 Requests'; AccountTypes = 'EA'; PricingBlockSize = 5000000; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '5000000000 Requests'; AccountTypes = 'EA'; PricingBlockSize = 5000000000; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '50K'; AccountTypes = 'MCA'; PricingBlockSize = 50000; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '60'; AccountTypes = 'EA'; PricingBlockSize = 60; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '60 '; AccountTypes = 'EA'; PricingBlockSize = 60; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '60 Minutes'; AccountTypes = 'EA'; PricingBlockSize = 60; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = '744 Connections'; AccountTypes = 'EA'; PricingBlockSize = 744; DistinctUnits = 'Connections'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'CallingMinutes'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Days'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Days'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'GB'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Gb / Month'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'GB/Month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Hours'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Hours'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'MB/month'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'MB/month'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Minute(s)'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Minutes'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Per Call'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Calls'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Per Request'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Text'; AccountTypes = 'MCA, EA'; PricingBlockSize = 1; DistinctUnits = 'Messages'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Unassigned'; AccountTypes = 'EA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Unit'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'Units'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Units'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'per Privacy Subject Rights Request'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Requests'; }
        ,[PSCustomObject]@{ UnitOfMeasure = 'print job'; AccountTypes = 'MCA'; PricingBlockSize = 1; DistinctUnits = 'Requests'; }
    )
}
