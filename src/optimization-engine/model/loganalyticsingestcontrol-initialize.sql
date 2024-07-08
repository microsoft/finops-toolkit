IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argvmexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argvmexports', '1901-01-01T00:00:00Z', -1, 'VMsV1', 'ARGVirtualMachine')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argdiskexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argdiskexports', '1901-01-01T00:00:00Z', -1, 'DisksV1', 'ARGManagedDisk')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argvhdexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argvhdexports', '1901-01-01T00:00:00Z', -1, 'VhdDisksV1', 'ARGUnmanagedDisk')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argavailsetexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argavailsetexports', '1901-01-01T00:00:00Z', -1, 'AvailSetsV1', 'ARGAvailabilitySet')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'advisorexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('advisorexports', '1901-01-01T00:00:00Z', -1, 'AdvisorV1', 'AzureAdvisor')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'remediationlogs')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('remediationlogs', '1901-01-01T00:00:00Z', -1, 'RemediationV1', 'RemediationLogs')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'consumptionexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('consumptionexports', '1901-01-01T00:00:00Z', -1, 'ConsumptionV1', 'AzureConsumption')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'aadobjectsexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('aadobjectsexports', '1901-01-01T00:00:00Z', -1, 'AADObjectsV1', 'AADObjects')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'arglbexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('arglbexports', '1901-01-01T00:00:00Z', -1, 'LoadBalancersV1', 'ARGLoadBalancer')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argappgwexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argappgwexports', '1901-01-01T00:00:00Z', -1, 'AppGatewaysV1', 'ARGAppGateway')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argrescontainersexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argrescontainersexports', '1901-01-01T00:00:00Z', -1, 'ResourceContainersV1', 'ARGResourceContainers')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'rbacexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('rbacexports', '1901-01-01T00:00:00Z', -1, 'RBACAssignmentsV1', 'RBACAssignments')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argvnetexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argvnetexports', '1901-01-01T00:00:00Z', -1, 'VNetsV1', 'ARGVirtualNetwork')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argnicexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argnicexports', '1901-01-01T00:00:00Z', -1, 'NICsV1', 'ARGNetworkInterface')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argnsgexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argnsgexports', '1901-01-01T00:00:00Z', -1, 'NSGsV1', 'ARGNSGRule')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argpublicipexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argpublicipexports', '1901-01-01T00:00:00Z', -1, 'PublicIPsV1', 'ARGPublicIP')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argvmssexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argvmssexports', '1901-01-01T00:00:00Z', -1, 'VMSSV1', 'ARGVMSS')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argsqldbexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argsqldbexports', '1901-01-01T00:00:00Z', -1, 'SqlDbV1', 'ARGSqlDb')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'azmonitorexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('azmonitorexports', '1901-01-01T00:00:00Z', -1, 'MonitorMetricsV1', 'MonitorMetrics')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'policystateexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('policystateexports', '1901-01-01T00:00:00Z', -1, 'PolicyStatesV1', 'PolicyStates')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'recommendationsexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('recommendationsexports', '2022-12-26T00:00:00Z', -1, 'RecommendationsV1', 'Recommendations')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'reservationsexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('reservationsexports', '1901-01-01T00:00:00Z', -1, 'ReservationsUsageV1', 'ReservationsUsage')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'argappserviceplanexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('argappserviceplanexports', '1901-01-01T00:00:00Z', -1, 'AppServicePlansV1', 'AppServicePlans')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'pricesheetexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('pricesheetexports', '1901-01-01T00:00:00Z', -1, 'PricesheetV1', 'Pricesheet')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'reservationspriceexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('reservationspriceexports', '1901-01-01T00:00:00Z', -1, 'ReservationsPriceV1', 'ReservationsPrice')
END

IF NOT EXISTS (SELECT * FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'savingsplansexports')
BEGIN
    INSERT INTO [dbo].[LogAnalyticsIngestControl] 
    VALUES ('savingsplansexports', '1901-01-01T00:00:00Z', -1, 'SavingsPlansUsageV1', 'SavingsPlansUsage')
END
