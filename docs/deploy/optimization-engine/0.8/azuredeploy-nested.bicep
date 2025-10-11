param projectLocation string
param templateLocation string

param storageAccountName string
param automationAccountName string
param sqlServerName string
param sqlServerAlreadyExists bool
param sqlDatabaseName string
param logAnalyticsReuse bool
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param logAnalyticsRetentionDays int
param sqlBackupRetentionDays int
param userObjectId string
param userPrincipalName string
param sqlAdminPrincipalType string

param cloudEnvironment string
param authenticationOption string
param baseTime string
param resourceTags object
param contributorRoleAssignmentGuid string

param argDiskExportJobId string = newGuid()
param argVhdExportJobId string = newGuid()
param argVmExportJobId string = newGuid()
param argVmssExportJobId string = newGuid()
param argAvailSetExportJobId string = newGuid()
param advisorExportJobId string = newGuid()
param consumptionExportJobId string = newGuid()
param aadObjectsExportJobId string = newGuid()
param argLoadBalancersExportJobId string = newGuid()
param argAppGWsExportJobId string = newGuid()
param rbacExportJobId string = newGuid()
param argResContainersExportJobId string = newGuid()
param argNICExportJobId string = newGuid()
param argNSGExportJobId string = newGuid()
param argPublicIPExportJobId string = newGuid()
param argVNetExportJobId string = newGuid()
param argSqlDbExportJobId string = newGuid()
param policyStateExportJobId string = newGuid()
param monitorVmssCpuMaxExportJobId string = newGuid()
param monitorVmssCpuAvgExportJobId string = newGuid()
param monitorVmssMemoryMinExportJobId string = newGuid()
param monitorSqlDbDtuMaxExportJobId string = newGuid()
param monitorSqlDbDtuAvgExportJobId string = newGuid()
param monitorAppServiceCpuMaxExportJobId string = newGuid()
param monitorAppServiceCpuAvgExportJobId string = newGuid()
param monitorAppServiceMemoryMaxExportJobId string = newGuid()
param monitorAppServiceMemoryAvgExportJobId string = newGuid()
param monitorDiskIOPSAvgExportJobId string = newGuid()
param monitorDiskMBPsAvgExportJobId string = newGuid()
param argAppServicePlanExportJobId string = newGuid()
param pricesheetExportJobId string = newGuid()
param reservationPricesExportJobId string = newGuid()
param reservationUsageExportJobId string = newGuid()
param savingsPlansUsageExportJobId string = newGuid()
param argDiskIngestJobId string = newGuid()
param argVhdIngestJobId string = newGuid()
param argVmIngestJobId string = newGuid()
param argVmssIngestJobId string = newGuid()
param argAvailSetIngestJobId string = newGuid()
param advisorIngestJobId string = newGuid()
param remediationLogsIngestJobId string = newGuid()
param consumptionIngestJobId string = newGuid()
param aadObjectsIngestJobId string = newGuid()
param argLoadBalancersIngestJobId string = newGuid()
param argAppGWsIngestJobId string = newGuid()
param argResContainersIngestJobId string = newGuid()
param rbacIngestJobId string = newGuid()
param argNICIngestJobId string = newGuid()
param argNSGIngestJobId string = newGuid()
param argPublicIPIngestJobId string = newGuid()
param argVNetIngestJobId string = newGuid()
param argSqlDbIngestJobId string = newGuid()
param policyStateIngestJobId string = newGuid()
param monitorIngestJobId string = newGuid()
param argAppServicePlanIngestJobId string = newGuid()
param pricesheetIngestJobId string = newGuid()
param reservationPricesIngestJobId string = newGuid()
param reservationUsageIngestJobId string = newGuid()
param savingsPlansUsageIngestJobId string = newGuid()
param unattachedDisksRecommendationJobId string = newGuid()
param advisorCostAugmentedRecommendationJobId string = newGuid()
param advisorAsIsRecommendationJobId string = newGuid()
param vmsHaRecommendationJobId string = newGuid()
param vmOptimizationsRecommendationJobId string = newGuid()
param aadExpiringCredsRecommendationJobId string = newGuid()
param unusedLoadBalancersRecommendationJobId string = newGuid()
param unusedAppGWsRecommendationJobId string = newGuid()
param armOptimizationsRecommendationJobId string = newGuid()
param vnetOptimizationsRecommendationJobId string = newGuid()
param vmssOptimizationsRecommendationJobId string = newGuid()
param sqldbOptimizationsRecommendationJobId string = newGuid()
param storageOptimizationsRecommendationJobId string = newGuid()
param appServiceOptimizationsRecommendationJobId string = newGuid()
param diskOptimizationsRecommendationJobId string = newGuid()
param recommendationsIngestJobId string = newGuid()
param recommendationsLogAnalyticsIngestJobId string = newGuid()
param suppressionsLogAnalyticsIngestJobId string = newGuid()
param recommendationsCleanUpJobId string = newGuid()

param roleContributor string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

var telemetryId = '00f120b5-2007-6120-0000-000000000a0e'
var finOpsToolkitVersion = loadTextContent('ftkver.txt')
var advisorExportsRunbookName = 'Export-AdvisorRecommendationsToBlobStorage'
var argVmExportsRunbookName = 'Export-ARGVirtualMachinesPropertiesToBlobStorage'
var argVmssExportsRunbookName = 'Export-ARGVMSSPropertiesToBlobStorage'
var argDisksExportsRunbookName = 'Export-ARGManagedDisksPropertiesToBlobStorage'
var argVhdExportsRunbookName = 'Export-ARGUnmanagedDisksPropertiesToBlobStorage'
var argAvailSetExportsRunbookName = 'Export-ARGAvailabilitySetPropertiesToBlobStorage'
var consumptionExportsRunbookName = 'Export-ConsumptionToBlobStorage'
var aadObjectsExportsRunbookName = 'Export-AADObjectsToBlobStorage'
var argLoadBalancersExportsRunbookName = 'Export-ARGLoadBalancerPropertiesToBlobStorage'
var argAppGWsExportsRunbookName = 'Export-ARGAppGatewayPropertiesToBlobStorage'
var argResContainersExportsRunbookName = 'Export-ARGResourceContainersPropertiesToBlobStorage'
var rbacExportsRunbookName = 'Export-RBACAssignmentsToBlobStorage'
var argNICExportsRunbookName = 'Export-ARGNICPropertiesToBlobStorage'
var argNSGExportsRunbookName = 'Export-ARGNSGPropertiesToBlobStorage'
var argVNetExportsRunbookName = 'Export-ARGVNetPropertiesToBlobStorage'
var argPublicIpExportsRunbookName = 'Export-ARGPublicIpPropertiesToBlobStorage'
var argSqlDbExportsRunbookName = 'Export-ARGSqlDatabasePropertiesToBlobStorage'
var policyStateExportsRunbookName = 'Export-PolicyComplianceToBlobStorage'
var monitorExportsRunbookName = 'Export-AzMonitorMetricsToBlobStorage'
var argAppServicePlanExportsRunbookName = 'Export-ARGAppServicePlanPropertiesToBlobStorage'
var reservationsExportsRunbookName = 'Export-ReservationsUsageToBlobStorage'
var reservationsPriceExportsRunbookName = 'Export-ReservationsPriceToBlobStorage'
var priceSheetExportsRunbookName = 'Export-PriceSheetToBlobStorage'
var savingsPlansExportsRunbookName = 'Export-SavingsPlansUsageToBlobStorage'
var advisorExportsScheduleName = 'AzureOptimization_ExportAdvisorWeekly'
var argExportsScheduleName = 'AzureOptimization_ExportARGDaily'
var consumptionExportsScheduleName = 'AzureOptimization_ExportConsumptionDaily'
var aadObjectsExportsScheduleName = 'AzureOptimization_ExportAADObjectsDaily'
var rbacExportsScheduleName = 'AzureOptimization_ExportRBACDaily'
var policyStateExportsScheduleName = 'AzureOptimization_ExportPolicyStateDaily'
var monitorVmssCpuMaxExportsScheduleName = 'AzureOptimization_ExportMonitorVmssCpuMaxHourly'
var monitorVmssCpuAvgExportsScheduleName = 'AzureOptimization_ExportMonitorVmssCpuAvgHourly'
var monitorVmssMemoryMinExportsScheduleName = 'AzureOptimization_ExportMonitorVmssMemoryMinHourly'
var monitorSqlDbDtuMaxExportsScheduleName = 'AzureOptimization_ExportMonitorSqlDbDtuMaxHourly'
var monitorSqlDbDtuAvgExportsScheduleName = 'AzureOptimization_ExportMonitorSqlDbDtuAvgHourly'
var monitorAppServiceCpuMaxExportsScheduleName = 'AzureOptimization_ExportMonitorAppServiceCpuMaxHourly'
var monitorAppServiceCpuAvgExportsScheduleName = 'AzureOptimization_ExportMonitorAppServiceCpuAvgHourly'
var monitorAppServiceMemoryMaxExportsScheduleName = 'AzureOptimization_ExportMonitorAppServiceMemoryMaxHourly'
var monitorAppServiceMemoryAvgExportsScheduleName = 'AzureOptimization_ExportMonitorAppServiceMemoryAvgHourly'
var monitorDiskIOPSAvgExportsScheduleName = 'AzureOptimization_ExportMonitorDiskIOPSHourly'
var monitorDiskMBPsAvgExportsScheduleName = 'AzureOptimization_ExportMonitorDiskMBPsHourly'
var priceExportsScheduleName = 'AzureOptimization_ExportPricesWeekly'
var reservationsUsageExportsScheduleName = 'AzureOptimization_ExportReservationsDaily'
var savingsPlansUsageExportsScheduleName = 'AzureOptimization_ExportSavingsPlansDaily'
var csvExportsSchedules = [
  {
    exportSchedule: argExportsScheduleName
    exportDescription: 'Daily Azure Resource Graph exports'
    exportTimeOffset: 'PT1H05M'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: advisorExportsScheduleName
    exportDescription: 'Weekly Azure Advisor exports'
    exportTimeOffset: 'PT1H15M'
    exportFrequency: 'Week'
  }
  {
    exportSchedule: consumptionExportsScheduleName
    exportDescription: 'Daily Azure Consumption exports'
    exportTimeOffset: 'PT1H'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: aadObjectsExportsScheduleName
    exportDescription: 'Daily Microsoft Entra Objects exports'
    exportTimeOffset: 'PT1H'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: rbacExportsScheduleName
    exportDescription: 'Daily Azure RBAC exports'
    exportTimeOffset: 'PT1H02M'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: policyStateExportsScheduleName
    exportDescription: 'Daily Azure Policy State exports'
    exportTimeOffset: 'PT1H'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: monitorVmssCpuAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for VMSS Percentage CPU (Avg.)'
    exportTimeOffset: 'PT1H15M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorVmssCpuMaxExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for VMSS Percentage CPU (Max.)'
    exportTimeOffset: 'PT1H15M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorVmssMemoryMinExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for VMSS Available Memory (Min.)'
    exportTimeOffset: 'PT1H15M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorSqlDbDtuMaxExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for SQL Database Percentage DTU (Max.)'
    exportTimeOffset: 'PT1H15M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorSqlDbDtuAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for SQL Database Percentage DTU (Avg.)'
    exportTimeOffset: 'PT1H16M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorAppServiceCpuAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for App Service Percentage CPU (Avg.)'
    exportTimeOffset: 'PT1H16M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorAppServiceCpuMaxExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for App Service Percentage CPU (Max.)'
    exportTimeOffset: 'PT1H16M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorAppServiceMemoryAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for App Service Percentage RAM (Avg.)'
    exportTimeOffset: 'PT1H16M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorAppServiceMemoryMaxExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for App Service Percentage RAM (Max.)'
    exportTimeOffset: 'PT1H17M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorDiskIOPSAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for Disk IOPS (Avg.)'
    exportTimeOffset: 'PT1H17M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: monitorDiskMBPsAvgExportsScheduleName
    exportDescription: 'Hourly Azure Monitor metrics exports for Disk MBPs (Avg.)'
    exportTimeOffset: 'PT1H17M'
    exportFrequency: 'Hour'
  }
  {
    exportSchedule: priceExportsScheduleName
    exportDescription: 'Weekly Pricesheet and Reservation Prices exports'
    exportTimeOffset: 'PT1H35M'
    exportFrequency: 'Week'
  }
  {
    exportSchedule: reservationsUsageExportsScheduleName
    exportDescription: 'Daily Reservation Usage exports'
    exportTimeOffset: 'PT2H'
    exportFrequency: 'Day'
  }
  {
    exportSchedule: savingsPlansUsageExportsScheduleName
    exportDescription: 'Daily Savings Plans Usage exports'
    exportTimeOffset: 'PT2H05M'
    exportFrequency: 'Day'
  }
]
var csvExports = [
  {
    runbookName: advisorExportsRunbookName
    isOneToMany: false
    containerName: 'advisorexports'
    variableName: 'AzureOptimization_AdvisorContainer'
    variableDescription: 'The Storage Account container where Azure Advisor exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestAdvisorWeekly'
    ingestDescription: 'Weekly Azure Advisor recommendations ingests'
    ingestTimeOffset: 'PT1H45M'
    ingestFrequency: 'Week'
    ingestJobId: advisorIngestJobId
    exportSchedule: advisorExportsScheduleName
    exportJobId: advisorExportJobId
  }
  {
    runbookName: argVmExportsRunbookName
    isOneToMany: false
    containerName: 'argvmexports'
    variableName: 'AzureOptimization_ARGVMContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Virtual Machine exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGVMsDaily'
    ingestDescription: 'Daily Azure Resource Graph Virtual Machines ingests'
    ingestTimeOffset: 'PT1H30M'
    ingestFrequency: 'Day'
    ingestJobId: argVmIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argVmExportJobId
  }
  {
    runbookName: argVmssExportsRunbookName
    isOneToMany: false
    containerName: 'argvmssexports'
    variableName: 'AzureOptimization_ARGVMSSContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph VMSS exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGVMSSDaily'
    ingestDescription: 'Daily Azure Resource Graph VMSS ingests'
    ingestTimeOffset: 'PT1H30M'
    ingestFrequency: 'Day'
    ingestJobId: argVmssIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argVmssExportJobId
  }
  {
    runbookName: argDisksExportsRunbookName
    isOneToMany: false
    containerName: 'argdiskexports'
    variableName: 'AzureOptimization_ARGDiskContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Managed Disks exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGDisksDaily'
    ingestDescription: 'Daily Azure Resource Graph Managed Disks ingests'
    ingestTimeOffset: 'PT1H30M'
    ingestFrequency: 'Day'
    ingestJobId: argDiskIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argDiskExportJobId
  }
  {
    runbookName: argVhdExportsRunbookName
    isOneToMany: false
    containerName: 'argvhdexports'
    variableName: 'AzureOptimization_ARGVhdContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Unmanaged Disks exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGVHDsDaily'
    ingestDescription: 'Daily Azure Resource Graph Unmanaged Disks ingests'
    ingestTimeOffset: 'PT1H30M'
    ingestFrequency: 'Day'
    ingestJobId: argVhdIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argVhdExportJobId
  }
  {
    runbookName: argAvailSetExportsRunbookName
    isOneToMany: false
    containerName: 'argavailsetexports'
    variableName: 'AzureOptimization_ARGAvailabilitySetContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Availability Set exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGAvailSetsDaily'
    ingestDescription: 'Daily Azure Resource Graph Availability Sets ingests'
    ingestTimeOffset: 'PT1H31M'
    ingestFrequency: 'Day'
    ingestJobId: argAvailSetIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argAvailSetExportJobId
  }
  {
    runbookName: consumptionExportsRunbookName
    isOneToMany: false
    containerName: 'consumptionexports'
    variableName: 'AzureOptimization_ConsumptionContainer'
    variableDescription: 'The Storage Account container where Azure Consumption exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestConsumptionDaily'
    ingestDescription: 'Daily Azure Consumption ingests'
    ingestTimeOffset: 'PT2H'
    ingestFrequency: 'Day'
    ingestJobId: consumptionIngestJobId
    exportSchedule: consumptionExportsScheduleName
    exportJobId: consumptionExportJobId
  }
  {
    runbookName: aadObjectsExportsRunbookName
    isOneToMany: false
    containerName: 'aadobjectsexports'
    variableName: 'AzureOptimization_AADObjectsContainer'
    variableDescription: 'The Storage Account container where Microsoft Entra Objects exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestAADObjectsDaily'
    ingestDescription: 'Daily Microsoft Entra Objects ingests'
    ingestTimeOffset: 'PT2H'
    ingestFrequency: 'Day'
    ingestJobId: aadObjectsIngestJobId
    exportSchedule: aadObjectsExportsScheduleName
    exportJobId: aadObjectsExportJobId
  }
  {
    runbookName: argLoadBalancersExportsRunbookName
    isOneToMany: false
    containerName: 'arglbexports'
    variableName: 'AzureOptimization_ARGLoadBalancerContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Load Balancer exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGLoadBalancersDaily'
    ingestDescription: 'Daily Azure Resource Graph Load Balancers ingests'
    ingestTimeOffset: 'PT1H31M'
    ingestFrequency: 'Day'
    ingestJobId: argLoadBalancersIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argLoadBalancersExportJobId
  }
  {
    runbookName: argAppGWsExportsRunbookName
    isOneToMany: false
    containerName: 'argappgwexports'
    variableName: 'AzureOptimization_ARGAppGatewayContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Application Gateway exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGAppGWsDaily'
    ingestDescription: 'Daily Azure Resource Graph Application Gateways ingests'
    ingestTimeOffset: 'PT1H31M'
    ingestFrequency: 'Day'
    ingestJobId: argAppGWsIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argAppGWsExportJobId
  }
  {
    runbookName: argResContainersExportsRunbookName
    isOneToMany: false
    containerName: 'argrescontainersexports'
    variableName: 'AzureOptimization_ARGResourceContainersContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Resource Containers exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGResourceContainersDaily'
    ingestDescription: 'Daily Azure Resource Graph Resource Containers ingests'
    ingestTimeOffset: 'PT1H32M'
    ingestFrequency: 'Day'
    ingestJobId: argResContainersIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argResContainersExportJobId
  }
  {
    runbookName: rbacExportsRunbookName
    isOneToMany: false
    containerName: 'rbacexports'
    variableName: 'AzureOptimization_RBACAssignmentsContainer'
    variableDescription: 'The Storage Account container where RBAC Assignments exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestRBACDaily'
    ingestDescription: 'Daily Azure RBAC ingests'
    ingestTimeOffset: 'PT1H32M'
    ingestFrequency: 'Day'
    ingestJobId: rbacIngestJobId
    exportSchedule: rbacExportsScheduleName
    exportJobId: rbacExportJobId
  }
  {
    runbookName: argNICExportsRunbookName
    isOneToMany: false
    containerName: 'argnicexports'
    variableName: 'AzureOptimization_ARGNICContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph NIC exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGNICsDaily'
    ingestDescription: 'Daily Azure Resource Graph NIC ingests'
    ingestTimeOffset: 'PT1H32M'
    ingestFrequency: 'Day'
    ingestJobId: argNICIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argNICExportJobId
  }
  {
    runbookName: argNSGExportsRunbookName
    isOneToMany: false
    containerName: 'argnsgexports'
    variableName: 'AzureOptimization_ARGNSGContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph NSG exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGNSGsDaily'
    ingestDescription: 'Daily Azure Resource Graph NSG ingests'
    ingestTimeOffset: 'PT1H32M'
    ingestFrequency: 'Day'
    ingestJobId: argNSGIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argNSGExportJobId
  }
  {
    runbookName: argVNetExportsRunbookName
    isOneToMany: false
    containerName: 'argvnetexports'
    variableName: 'AzureOptimization_ARGVNetContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph VNet exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGVNetsDaily'
    ingestDescription: 'Daily Azure Resource Graph Virtual Network ingests'
    ingestTimeOffset: 'PT1H33M'
    ingestFrequency: 'Day'
    ingestJobId: argVNetIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argVNetExportJobId
  }
  {
    runbookName: argPublicIpExportsRunbookName
    isOneToMany: false
    containerName: 'argpublicipexports'
    variableName: 'AzureOptimization_ARGPublicIpContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph Public IP exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGPublicIPsDaily'
    ingestDescription: 'Daily Azure Resource Graph Public IP ingests'
    ingestTimeOffset: 'PT1H33M'
    ingestFrequency: 'Day'
    ingestJobId: argPublicIPIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argPublicIPExportJobId
  }
  {
    runbookName: argSqlDbExportsRunbookName
    isOneToMany: false
    containerName: 'argsqldbexports'
    variableName: 'AzureOptimization_ARGSqlDatabaseContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph SQL DB exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGSqlDbDaily'
    ingestDescription: 'Daily Azure Resource Graph SQL DB ingests'
    ingestTimeOffset: 'PT1H33M'
    ingestFrequency: 'Day'
    ingestJobId: argSqlDbIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argSqlDbExportJobId
  }
  {
    runbookName: policyStateExportsRunbookName
    isOneToMany: false
    containerName: 'policystateexports'
    variableName: 'AzureOptimization_PolicyStatesContainer'
    variableDescription: 'The Storage Account container where Azure Policy State exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestPolicyStateDaily'
    ingestDescription: 'Daily Azure Policy State ingests'
    ingestTimeOffset: 'PT1H33M'
    ingestFrequency: 'Day'
    ingestJobId: policyStateIngestJobId
    exportSchedule: policyStateExportsScheduleName
    exportJobId: policyStateExportJobId
  }
  {
    runbookName: monitorExportsRunbookName
    isOneToMany: true
    containerName: 'azmonitorexports'
    variableName: 'AzureOptimization_AzMonitorContainer'
    variableDescription: 'The Storage Account container where Azure Monitor metrics exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestAzMonitorMetricsHourly'
    ingestDescription: 'Hourly Azure Monitor metrics ingests'
    ingestTimeOffset: 'PT2H'
    ingestFrequency: 'Hour'
    ingestJobId: monitorIngestJobId
    exportSchedule: null
    exportJobId: 'dummy'
  }
  {
    runbookName: argAppServicePlanExportsRunbookName
    isOneToMany: false
    containerName: 'argappserviceplanexports'
    variableName: 'AzureOptimization_ARGAppServicePlanContainer'
    variableDescription: 'The Storage Account container where Azure Resource Graph App Service Plan exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestARGAppServicePlanDaily'
    ingestDescription: 'Daily Azure Resource Graph App Service Plan ingests'
    ingestTimeOffset: 'PT1H34M'
    ingestFrequency: 'Day'
    ingestJobId: argAppServicePlanIngestJobId
    exportSchedule: argExportsScheduleName
    exportJobId: argAppServicePlanExportJobId
  }
  {
    runbookName: priceSheetExportsRunbookName
    isOneToMany: false
    containerName: 'pricesheetexports'
    variableName: 'AzureOptimization_PriceSheetContainer'
    variableDescription: 'The Storage Account container where Pricesheet exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestPricesheetWeekly'
    ingestDescription: 'Weekly Pricesheet ingests'
    ingestTimeOffset: 'PT2H'
    ingestFrequency: 'Week'
    ingestJobId: pricesheetIngestJobId
    exportSchedule: priceExportsScheduleName
    exportJobId: pricesheetExportJobId
  }
  {
    runbookName: reservationsPriceExportsRunbookName
    isOneToMany: false
    containerName: 'reservationspriceexports'
    variableName: 'AzureOptimization_ReservationsPriceContainer'
    variableDescription: 'The Storage Account container where Reservations Prices exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestReservationsPriceWeekly'
    ingestDescription: 'Weekly Reservations Prices ingests'
    ingestTimeOffset: 'PT2H'
    ingestFrequency: 'Week'
    ingestJobId: reservationPricesIngestJobId
    exportSchedule: priceExportsScheduleName
    exportJobId: reservationPricesExportJobId
  }
  {
    runbookName: reservationsExportsRunbookName
    isOneToMany: false
    containerName: 'reservationsexports'
    variableName: 'AzureOptimization_ReservationsContainer'
    variableDescription: 'The Storage Account container where Reservations Usage exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestReservationsUsageDaily'
    ingestDescription: 'Daily Reservations Usage ingests'
    ingestTimeOffset: 'PT2H30M'
    ingestFrequency: 'Day'
    ingestJobId: reservationUsageIngestJobId
    exportSchedule: reservationsUsageExportsScheduleName
    exportJobId: reservationUsageExportJobId
  }
  {
    runbookName: savingsPlansExportsRunbookName
    isOneToMany: false
    containerName: 'savingsplansexports'
    variableName: 'AzureOptimization_SavingsPlansContainer'
    variableDescription: 'The Storage Account container where Savings Plans Usage exports are dumped to'
    ingestSchedule: 'AzureOptimization_IngestSavingsPlansUsageDaily'
    ingestDescription: 'Daily Savings Plans Usage ingests'
    ingestTimeOffset: 'PT2H35M'
    ingestFrequency: 'Day'
    ingestJobId: savingsPlansUsageIngestJobId
    exportSchedule: savingsPlansUsageExportsScheduleName
    exportJobId: savingsPlansUsageExportJobId
  }
]
var csvParameterizedExports = [
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorVmssCpuMaxExportsScheduleName
    exportJobId: monitorVmssCpuMaxExportJobId
    parameters: {
      ResourceType: 'microsoft.compute/virtualmachinescalesets'
      TimeSpan: '01:00:00'
      aggregationType: 'Maximum'
      MetricNames: 'Percentage CPU'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorVmssCpuAvgExportsScheduleName
    exportJobId: monitorVmssCpuAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.compute/virtualmachinescalesets'
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      MetricNames: 'Percentage CPU'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorVmssMemoryMinExportsScheduleName
    exportJobId: monitorVmssMemoryMinExportJobId
    parameters: {
      ResourceType: 'microsoft.compute/virtualmachinescalesets'
      TimeSpan: '01:00:00'
      aggregationType: 'Minimum'
      MetricNames: 'Available Memory Bytes'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorSqlDbDtuMaxExportsScheduleName
    exportJobId: monitorSqlDbDtuMaxExportJobId
    parameters: {
      ResourceType: 'microsoft.sql/servers/databases'
      ARGFilter: 'sku.tier in (\'Standard\',\'Premium\')'
      TimeSpan: '01:00:00'
      aggregationType: 'Maximum'
      MetricNames: 'dtu_consumption_percent'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorSqlDbDtuAvgExportsScheduleName
    exportJobId: monitorSqlDbDtuAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.sql/servers/databases'
      ARGFilter: 'sku.tier in (\'Standard\',\'Premium\')'
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      AggregationOfType: 'Maximum'
      MetricNames: 'dtu_consumption_percent'
      TimeGrain: '00:01:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorAppServiceCpuMaxExportsScheduleName
    exportJobId: monitorAppServiceCpuMaxExportJobId
    parameters: {
      ResourceType: 'microsoft.web/serverfarms'
      ARGFilter: 'properties.computeMode == \'Dedicated\' and sku.tier != \'Free\''
      TimeSpan: '01:00:00'
      aggregationType: 'Maximum'
      MetricNames: 'CpuPercentage'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorAppServiceCpuAvgExportsScheduleName
    exportJobId: monitorAppServiceCpuAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.web/serverfarms'
      ARGFilter: 'properties.computeMode == \'Dedicated\' and sku.tier != \'Free\''
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      AggregationOfType: 'Maximum'
      MetricNames: 'CpuPercentage'
      TimeGrain: '00:01:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorAppServiceMemoryMaxExportsScheduleName
    exportJobId: monitorAppServiceMemoryMaxExportJobId
    parameters: {
      ResourceType: 'microsoft.web/serverfarms'
      ARGFilter: 'properties.computeMode == \'Dedicated\' and sku.tier != \'Free\''
      TimeSpan: '01:00:00'
      aggregationType: 'Maximum'
      MetricNames: 'MemoryPercentage'
      TimeGrain: '01:00:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorAppServiceMemoryAvgExportsScheduleName
    exportJobId: monitorAppServiceMemoryAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.web/serverfarms'
      ARGFilter: 'properties.computeMode == \'Dedicated\' and sku.tier != \'Free\''
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      AggregationOfType: 'Maximum'
      MetricNames: 'MemoryPercentage'
      TimeGrain: '00:01:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorDiskIOPSAvgExportsScheduleName
    exportJobId: monitorDiskIOPSAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.compute/disks'
      ARGFilter: 'sku.name startswith \'Premium_\' and properties.diskState =~ \'Attached\''
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      AggregationOfType: 'Maximum'
      MetricNames: 'Composite Disk Read Operations/sec,Composite Disk Write Operations/sec'
      TimeGrain: '00:01:00'
    }
  }
  {
    runbookName: monitorExportsRunbookName
    exportSchedule: monitorDiskMBPsAvgExportsScheduleName
    exportJobId: monitorDiskMBPsAvgExportJobId
    parameters: {
      ResourceType: 'microsoft.compute/disks'
      ARGFilter: 'sku.name startswith \'Premium_\' and properties.diskState =~ \'Attached\''
      TimeSpan: '01:00:00'
      aggregationType: 'Average'
      AggregationOfType: 'Maximum'
      MetricNames: 'Composite Disk Read Bytes/sec,Composite Disk Write Bytes/sec'
      TimeGrain: '00:01:00'
    }
  }
]
var unattachedDisksRecommendationsRunbookName = 'Recommend-UnattachedDisksToBlobStorage'
var advisorCostAugmentedRecommendationsRunbookName = 'Recommend-AdvisorCostAugmentedToBlobStorage'
var advisorAsIsRecommendationsRunbookName = 'Recommend-AdvisorAsIsToBlobStorage'
var vmsHARecommendationsRunbookName = 'Recommend-VMsHighAvailabilityToBlobStorage'
var vmOptimizationsRecommendationsRunbookName = 'Recommend-VMOptimizationsToBlobStorage'
var aadExpiringCredsRecommendationsRunbookName = 'Recommend-AADExpiringCredentialsToBlobStorage'
var unusedLBsRecommendationsRunbookName = 'Recommend-UnusedLoadBalancersToBlobStorage'
var unusedAppGWsRecommendationsRunbookName = 'Recommend-UnusedAppGWsToBlobStorage'
var armOptimizationsRecommendationsRunbookName = 'Recommend-ARMOptimizationsToBlobStorage'
var vnetOptimizationsRecommendationsRunbookName = 'Recommend-VNetOptimizationsToBlobStorage'
var vmssOptimizationsRecommendationsRunbookName = 'Recommend-VMSSOptimizationsToBlobStorage'
var sqldbOptimizationsRecommendationsRunbookName = 'Recommend-SqlDbOptimizationsToBlobStorage'
var storageOptimizationsRecommendationsRunbookName = 'Recommend-StorageAccountOptimizationsToBlobStorage'
var appServiceOptimizationsRecommendationsRunbookName = 'Recommend-AppServiceOptimizationsToBlobStorage'
var diskOptimizationsRecommendationsRunbookName = 'Recommend-DiskOptimizationsToBlobStorage'
var cleanUpOlderRecommendationsRunbookName = 'CleanUp-OlderRecommendationsFromSqlServer'
var recommendations = [
  {
    recommendationJobId: unattachedDisksRecommendationJobId
    runbookName: unattachedDisksRecommendationsRunbookName
  }
  {
    recommendationJobId: advisorCostAugmentedRecommendationJobId
    runbookName: advisorCostAugmentedRecommendationsRunbookName
  }
  {
    recommendationJobId: advisorAsIsRecommendationJobId
    runbookName: advisorAsIsRecommendationsRunbookName
  }
  {
    recommendationJobId: vmsHaRecommendationJobId
    runbookName: vmsHARecommendationsRunbookName
  }
  {
    recommendationJobId: vmOptimizationsRecommendationJobId
    runbookName: vmOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: aadExpiringCredsRecommendationJobId
    runbookName: aadExpiringCredsRecommendationsRunbookName
  }
  {
    recommendationJobId: unusedLoadBalancersRecommendationJobId
    runbookName: unusedLBsRecommendationsRunbookName
  }
  {
    recommendationJobId: unusedAppGWsRecommendationJobId
    runbookName: unusedAppGWsRecommendationsRunbookName
  }
  {
    recommendationJobId: armOptimizationsRecommendationJobId
    runbookName: armOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: vnetOptimizationsRecommendationJobId
    runbookName: vnetOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: vmssOptimizationsRecommendationJobId
    runbookName: vmssOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: sqldbOptimizationsRecommendationJobId
    runbookName: sqldbOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: storageOptimizationsRecommendationJobId
    runbookName: storageOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: appServiceOptimizationsRecommendationJobId
    runbookName: appServiceOptimizationsRecommendationsRunbookName
  }
  {
    recommendationJobId: diskOptimizationsRecommendationJobId
    runbookName: diskOptimizationsRecommendationsRunbookName
  }
]
var remediationLogsContainerName = 'remediationlogs'
var recommendationsContainerName = 'recommendationsexports'
var csvIngestRunbookName = 'Ingest-OptimizationCSVExportsToLogAnalytics'
var recommendationsIngestRunbookName = 'Ingest-RecommendationsToSQLServer'
var recommendationsLogAnalyticsIngestRunbookName = 'Ingest-RecommendationsToLogAnalytics'
var suppressionsLogAnalyticsIngestRunbookName = 'Ingest-SuppressionsToLogAnalytics'
var advisorRightSizeFilteredRemediationRunbookName = 'Remediate-AdvisorRightSizeFiltered'
var longDeallocatedVMsFilteredRemediationRunbookName = 'Remediate-LongDeallocatedVMsFiltered'
var unattachedDisksFilteredRemediationRunbookName = 'Remediate-UnattachedDisksFiltered'
var remediationLogsIngestScheduleName = 'AzureOptimization_IngestRemediationLogsDaily'
var recommendationsScheduleName = 'AzureOptimization_RecommendationsWeekly'
var recommendationsIngestScheduleName = 'AzureOptimization_IngestRecommendationsWeekly'
var suppressionsIngestScheduleName = 'AzureOptimization_IngestSuppressionsWeekly'
var recommendationsCleanUpScheduleName = 'AzureOptimization_CleanUpRecommendationsWeekly'
var Az_Accounts = {
  name: 'Az.Accounts'
  url: 'https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.12.1'
}
var Microsoft_Graph_Authentication = {
  name: 'Microsoft.Graph.Authentication'
  url: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication/2.4.0'
}
var psModules = [
  {
    name: 'Az.Compute'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.Compute/5.7.0'
  }
  {
    name: 'Az.OperationalInsights'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.OperationalInsights/3.2.0'
  }
  {
    name: 'Az.ResourceGraph'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.ResourceGraph/0.13.0'
  }
  {
    name: 'Az.Storage'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.Storage/5.5.0'
  }
  {
    name: 'Az.Resources'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.Resources/6.6.0'
  }
  {
    name: 'Az.Monitor'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.Monitor/4.4.1'
  }
  {
    name: 'Az.PolicyInsights'
    url: 'https://www.powershellgallery.com/api/v2/package/Az.PolicyInsights/1.6.0'
  }
  {
    name: 'Microsoft.Graph.Users'
    url: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Users/2.4.0'
  }
  {
    name: 'Microsoft.Graph.Groups'
    url: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Groups/2.4.0'
  }
  {
    name: 'Microsoft.Graph.Applications'
    url: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Applications/2.4.0'
  }
  {
    name: 'Microsoft.Graph.Identity.DirectoryManagement'
    url: 'https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Identity.DirectoryManagement/2.4.0'
  }
]
var runbooks = [
  {
    name: advisorExportsRunbookName
    version: '1.4.3.0'
    description: 'Exports Azure Advisor recommendations to Blob Storage using the Advisor API'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${advisorExportsRunbookName}.ps1')
  }
  {
    name: argDisksExportsRunbookName
    version: '1.3.5.0'
    description: 'Exports Managed Disks properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argDisksExportsRunbookName}.ps1')
  }
  {
    name: argVhdExportsRunbookName
    version: '1.1.5.0'
    description: 'Exports Unmanaged Disks (owned by a VM) properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argVhdExportsRunbookName}.ps1')
  }
  {
    name: argVmExportsRunbookName
    version: '1.4.5.0'
    description: 'Exports Virtual Machine properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argVmExportsRunbookName}.ps1')
  }
  {
    name: argVmssExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports VMSS properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argVmssExportsRunbookName}.ps1')
  }
  {
    name: argAvailSetExportsRunbookName
    version: '1.1.5.0'
    description: 'Exports Availability Set properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argAvailSetExportsRunbookName}.ps1')
  }
  {
    name: consumptionExportsRunbookName
    version: '2.1.1.0'
    description: 'Exports Azure Consumption events to Blob Storage using Azure Consumption API'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${consumptionExportsRunbookName}.ps1')
  }
  {
    name: aadObjectsExportsRunbookName
    version: '1.3.1.0'
    description: 'Exports Azure AAD Objects to Blob Storage using Azure ARM API'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${aadObjectsExportsRunbookName}.ps1')
  }
  {
    name: argLoadBalancersExportsRunbookName
    version: '1.1.5.0'
    description: 'Exports Load Balancer properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argLoadBalancersExportsRunbookName}.ps1')
  }
  {
    name: argAppGWsExportsRunbookName
    version: '1.1.5.0'
    description: 'Exports Application Gateway properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argAppGWsExportsRunbookName}.ps1')
  }
  {
    name: argResContainersExportsRunbookName
    version: '1.0.6.0'
    description: 'Exports Resource Containers properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argResContainersExportsRunbookName}.ps1')
  }
  {
    name: rbacExportsRunbookName
    version: '1.1.1.0'
    description: 'Exports RBAC assignments to Blob Storage using ARM and Microsoft Entra'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${rbacExportsRunbookName}.ps1')
  }
  {
    name: argNICExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports NIC properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argNICExportsRunbookName}.ps1')
  }
  {
    name: argNSGExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports NSG properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argNSGExportsRunbookName}.ps1')
  }
  {
    name: argPublicIpExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports Public IP properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argPublicIpExportsRunbookName}.ps1')
  }
  {
    name: argVNetExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports VNet properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argVNetExportsRunbookName}.ps1')
  }
  {
    name: argSqlDbExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports SQL DB properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argSqlDbExportsRunbookName}.ps1')
  }
  {
    name: policyStateExportsRunbookName
    version: '1.0.4.0'
    description: 'Exports Azure Policy State to Blob Storage'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${policyStateExportsRunbookName}.ps1')
  }
  {
    name: monitorExportsRunbookName
    version: '1.0.3.0'
    description: 'Exports Azure Monitor metrics to Blob Storage'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${monitorExportsRunbookName}.ps1')
  }
  {
    name: argAppServicePlanExportsRunbookName
    version: '1.0.2.0'
    description: 'Exports App Service Plan properties to Blob Storage using Azure Resource Graph'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${argAppServicePlanExportsRunbookName}.ps1')
  }
  {
    name: reservationsExportsRunbookName
    version: '1.1.3.0'
    description: 'Exports Reservations Usage to Blob Storage using the EA or MCA APIs'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${reservationsExportsRunbookName}.ps1')
  }
  {
    name: reservationsPriceExportsRunbookName
    version: '1.0.2.0'
    description: 'Exports Reservations Prices to Blob Storage using the Retail Prices API'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${reservationsPriceExportsRunbookName}.ps1')
  }
  {
    name: priceSheetExportsRunbookName
    version: '1.1.2.0'
    description: 'Exports Price Sheet to Blob Storage using the EA or MCA APIs'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${priceSheetExportsRunbookName}.ps1')
  }
  {
    name: savingsPlansExportsRunbookName
    version: '1.0.2.0'
    description: 'Exports Savings Plans Usage to Blob Storage using the EA or MCA APIs'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${savingsPlansExportsRunbookName}.ps1')
  }
  {
    name: csvIngestRunbookName
    version: '1.6.2.0'
    description: 'Ingests CSV blobs as custom logs to Log Analytics'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/data-collection/${csvIngestRunbookName}.ps1')
  }
  {
    name: unattachedDisksRecommendationsRunbookName
    version: '2.5.1.0'
    description: 'Generates unattached disks recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${unattachedDisksRecommendationsRunbookName}.ps1')
  }
  {
    name: advisorCostAugmentedRecommendationsRunbookName
    version: '2.10.1.0'
    description: 'Generates augmented Advisor Cost recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${advisorCostAugmentedRecommendationsRunbookName}.ps1')
  }
  {
    name: advisorAsIsRecommendationsRunbookName
    version: '1.6.1.0'
    description: 'Generates all types of Advisor recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${advisorAsIsRecommendationsRunbookName}.ps1')
  }
  {
    name: vmsHARecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates VMs High Availability recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${vmsHARecommendationsRunbookName}.ps1')
  }
  {
    name: vmOptimizationsRecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates VM optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${vmOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: aadExpiringCredsRecommendationsRunbookName
    version: '1.2.1.0'
    description: 'Generates AAD Objects with expiring credentials recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${aadExpiringCredsRecommendationsRunbookName}.ps1')
  }
  {
    name: unusedLBsRecommendationsRunbookName
    version: '1.3.1.0'
    description: 'Generates unused Load Balancers recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${unusedLBsRecommendationsRunbookName}.ps1')
  }
  {
    name: unusedAppGWsRecommendationsRunbookName
    version: '1.3.1.0'
    description: 'Generates unused Application Gateways recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${unusedAppGWsRecommendationsRunbookName}.ps1')
  }
  {
    name: armOptimizationsRecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates ARM optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${armOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: vnetOptimizationsRecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates Virtual Network optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${vnetOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: vmssOptimizationsRecommendationsRunbookName
    version: '1.2.1.0'
    description: 'Generates VM Scale Set optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${vmssOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: sqldbOptimizationsRecommendationsRunbookName
    version: '1.2.1.0'
    description: 'Generates SQL DB optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${sqldbOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: storageOptimizationsRecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates Storage Account optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${storageOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: appServiceOptimizationsRecommendationsRunbookName
    version: '1.1.1.0'
    description: 'Generates App Service optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${appServiceOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: diskOptimizationsRecommendationsRunbookName
    version: '1.2.1.0'
    description: 'Generates Disk optimizations recommendations'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${diskOptimizationsRecommendationsRunbookName}.ps1')
  }
  {
    name: recommendationsIngestRunbookName
    version: '1.7.1.0'
    description: 'Ingests JSON-based recommendations into an Azure SQL Database'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${recommendationsIngestRunbookName}.ps1')
  }
  {
    name: recommendationsLogAnalyticsIngestRunbookName
    version: '1.1.1.0'
    description: 'Ingests JSON-based recommendations into Log Analytics'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${recommendationsLogAnalyticsIngestRunbookName}.ps1')
  }
  {
    name: suppressionsLogAnalyticsIngestRunbookName
    version: '1.1.0.0'
    description: 'Ingests suppressions into Log Analytics'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/recommendations/${suppressionsLogAnalyticsIngestRunbookName}.ps1')
  }
  {
    name: advisorRightSizeFilteredRemediationRunbookName
    version: '1.3.1.0'
    description: 'Remediates Azure Advisor right-size recommendations given fit and tag filters'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/remediations/${advisorRightSizeFilteredRemediationRunbookName}.ps1')
  }
  {
    name: longDeallocatedVMsFilteredRemediationRunbookName
    version: '1.1.1.0'
    description: 'Remediates long-deallocated VMs recommendations given fit and tag filters'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/remediations/${longDeallocatedVMsFilteredRemediationRunbookName}.ps1')
  }
  {
    name: unattachedDisksFilteredRemediationRunbookName
    version: '1.1.1.0'
    description: 'Remediates unattached disks recommendations given fit and tag filters'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/remediations/${unattachedDisksFilteredRemediationRunbookName}.ps1')
  }
  {
    name: cleanUpOlderRecommendationsRunbookName
    version: '1.1.0.0'
    description: 'Cleans up older recommendations from SQL Database'
    type: 'PowerShell'
    scriptUri: uri(templateLocation, 'runbooks/maintenance/${cleanUpOlderRecommendationsRunbookName}.ps1')
  }
]
var automationVariables = [
  {
    name: 'AzureOptimization_CloudEnvironment'
    description: 'Azure Cloud environment (e.g., AzureCloud, AzureChinaCloud, etc.)'
    value: '"${cloudEnvironment}"'
  }
  {
    name: 'AzureOptimization_AuthenticationOption'
    description: 'Runbook authentication type (RunAsAccount or ManagedIdentity)'
    value: '"${authenticationOption}"'
  }
  {
    name: 'AzureOptimization_StorageSink'
    description: 'The Azure Storage Account where data source exports are dumped to'
    value: '"${storageAccountName}"'
  }
  {
    name: 'AzureOptimization_ConsumptionOffsetDays'
    description: 'The offset (in days) for querying for consumption data'
    value: 3
  }
  {
    name: 'AzureOptimization_AdvisorFilter'
    description: 'The category filter to use for Azure Advisor (non-Cost) recommendations exports'
    value: '"HighAvailability,Security,Performance,OperationalExcellence"'
  }
  {
    name: 'AzureOptimization_ReferenceRegion'
    description: 'The Azure region used as a reference for getting details about Azure VM sizes available'
    value: '"${projectLocation}"'
  }
  {
    name: 'AzureOptimization_SQLServerDatabase'
    description: 'The Azure SQL Database name for the ingestion control and recommendations tables'
    value: '"${sqlDatabaseName}"'
  }
  {
    name: 'AzureOptimization_LogAnalyticsChunkSize'
    description: 'The size (in rows) for each chunk of Log Analytics ingestion request'
    value: 6000
  }
  {
    name: 'AzureOptimization_StorageBlobsPageSize'
    description: 'The size (in blobs count) for each page of Storage Account container blob listing'
    value: 1000
  }
  {
    name: 'AzureOptimization_SQLServerInsertSize'
    description: 'The size (in inserted lines) for each page of recommendations ingestion into the SQL Database'
    value: 900
  }
  {
    name: 'AzureOptimization_LogAnalyticsLogPrefix'
    description: 'The prefix for all Azure Optimization custom log tables in Log Analytics'
    value: '"AzureOptimization"'
  }
  {
    name: 'AzureOptimization_LogAnalyticsWorkspaceName'
    description: 'The Log Analytics Workspace Name where optimization data will be ingested'
    value: '"${logAnalyticsWorkspaceName}"'
  }
  {
    name: 'AzureOptimization_LogAnalyticsWorkspaceRG'
    description: 'The resource group for the Log Analytics Workspace where optimization data will be ingested'
    value: '"${((!logAnalyticsReuse) ? resourceGroup().name : logAnalyticsWorkspaceRG)}"'
  }
  {
    name: 'AzureOptimization_LogAnalyticsWorkspaceSubId'
    description: 'The Azure subscription for the Log Analytics Workspace where optimization data will be ingested'
    value: '"${subscription().subscriptionId}"'
  }
  {
    name: 'AzureOptimization_LogAnalyticsWorkspaceTenantId'
    description: 'The Microsoft Entra tenant for the Log Analytics Workspace where optimization data will be ingested'
    value: '"${subscription().tenantId}"'
  }
  {
    name: 'AzureOptimization_PriceSheetMeterCategories'
    description: 'Comma-separated meter categories to be included in the Price Sheet (remove variable to include all categories)'
    value: '"Virtual Machines,Storage"'
  }
  {
    name: 'AzureOptimization_RetailPricesCurrencyCode'
    description: 'The currency code to be used for the retail prices exports (used for Reservations prices)'
    value: '"EUR"'
  }
  {
    name: 'AzureOptimization_RecommendAdvisorPeriodInDays'
    description: 'The period (in days) to look back for Advisor exported recommendations'
    value: 7
  }
  {
    name: 'AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays'
    description: 'The period (in days) for considering a VM long deallocated'
    value: 30
  }
  {
    name: 'AzureOptimization_PerfPercentileCpu'
    description: 'The percentile to be used for processor metrics'
    value: 99
  }
  {
    name: 'AzureOptimization_PerfPercentileMemory'
    description: 'The percentile to be used for memory metrics'
    value: 99
  }
  {
    name: 'AzureOptimization_PerfPercentileNetwork'
    description: 'The percentile to be used for network metrics'
    value: 99
  }
  {
    name: 'AzureOptimization_PerfPercentileDisk'
    description: 'The percentile to be used for disk metrics'
    value: 99
  }
  {
    name: 'AzureOptimization_PerfPercentileSqlDtu'
    description: 'The percentile to be used for SQL DB DTU metrics'
    value: 99
  }
  {
    name: 'AzureOptimization_PerfThresholdCpuPercentage'
    description: 'The processor usage percentage threshold above which the fit score is decreased or below which the instance is considered underutilized'
    value: 30
  }
  {
    name: 'AzureOptimization_PerfThresholdMemoryPercentage'
    description: 'The memory usage percentage threshold above which the fit score is decreased or below which the instance is considered underutilized'
    value: 50
  }
  {
    name: 'AzureOptimization_PerfThresholdCpuDegradedMaxPercentage'
    description: 'The maximum processor usage percentage threshold above which the instance is considered degraded'
    value: 95
  }
  {
    name: 'AzureOptimization_PerfThresholdCpuDegradedAvgPercentage'
    description: 'The average processor usage percentage threshold above which the instance is considered degraded'
    value: 75
  }
  {
    name: 'AzureOptimization_PerfThresholdMemoryDegradedPercentage'
    description: 'The memory usage percentage threshold above which the instance is considered degraded'
    value: 90
  }
  {
    name: 'AzureOptimization_PerfThresholdNetworkMbps'
    description: 'The network usage threshold (in Mbps) above which the fit score is decreased'
    value: 750
  }
  {
    name: 'AzureOptimization_PerfThresholdCpuShutdownPercentage'
    description: 'The processor usage percentage threshold above which the fit score is decreased (shutdown scenarios)'
    value: 5
  }
  {
    name: 'AzureOptimization_PerfThresholdMemoryShutdownPercentage'
    description: 'The memory usage percentage threshold above which the fit score is decreased (shutdown scenarios)'
    value: 100
  }
  {
    name: 'AzureOptimization_PerfThresholdNetworkShutdownMbps'
    description: 'The network usage threshold (in Mbps) above which the fit score is decreased (shutdown scenarios)'
    value: 10
  }
  {
    name: 'AzureOptimization_PerfThresholdDtuPercentage'
    description: 'The DTU usage percentage threshold below which a SQL Database instance is considered underutilized'
    value: 40
  }
  {
    name: 'AzureOptimization_PerfThresholdDtuDegradedPercentage'
    description: 'The DTU usage percentage threshold above which a SQL Database instance is considered performance degraded'
    value: 75
  }
  {
    name: 'AzureOptimization_PerfThresholdDiskIOPSPercentage'
    description: 'The IOPS usage percentage threshold below which a Disk is considered underutilized'
    value: 5
  }
  {
    name: 'AzureOptimization_PerfThresholdDiskMBsPercentage'
    description: 'The throughput (MBps) usage percentage threshold below which a Disk is considered underutilized'
    value: 5
  }
  {
    name: 'AzureOptimization_RemediateRightSizeMinFitScore'
    description: 'The minimum fit score for right-size remediation'
    value: '"5.0"'
  }
  {
    name: 'AzureOptimization_RemediateRightSizeMinWeeksInARow'
    description: 'The minimum number of weeks in a row required for a right-size recommendation to be remediated'
    value: 4
  }
  {
    name: 'AzureOptimization_RecommendationAdvisorCostRightSizeId'
    description: 'The Azure Advisor VM right-size recommendation ID'
    value: '"e10b1381-5f0a-47ff-8c7b-37bd13d7c974"'
  }
  {
    name: 'AzureOptimization_RemediateLongDeallocatedVMsMinFitScore'
    description: 'The minimum fit score for long-deallocated VM remediation'
    value: '"5.0"'
  }
  {
    name: 'AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow'
    description: 'The minimum number of weeks in a row required for a long-deallocated VM recommendation to be remediated'
    value: 4
  }
  {
    name: 'AzureOptimization_RecommendationLongDeallocatedVMsId'
    description: 'The long deallocated VM recommendation ID'
    value: '"c320b790-2e58-452a-aa63-7b62c383ad8a"'
  }
  {
    name: 'AzureOptimization_RemediateUnattachedDisksMinFitScore'
    description: 'The minimum fit score for unattached disk remediation'
    value: '"5.0"'
  }
  {
    name: 'AzureOptimization_RemediateUnattachedDisksMinWeeksInARow'
    description: 'The minimum number of weeks in a row required for a unattached disk recommendation to be remediated'
    value: 4
  }
  {
    name: 'AzureOptimization_RemediateUnattachedDisksAction'
    description: 'The action for the unattached disk recommendation to be remediated (Delete or Downsize)'
    value: '"Delete"'
  }
  {
    name: 'AzureOptimization_RecommendationUnattachedDisksId'
    description: 'The unattached disk recommendation ID'
    value: '"c84d5e86-e2d6-4d62-be7c-cecfbd73b0db"'
  }
  {
    name: 'AzureOptimization_RecommendationAADMinCredValidityDays'
    description: 'The minimum validity of an AAD Object credential in days'
    value: 30
  }
  {
    name: 'AzureOptimization_RecommendationAADMaxCredValidityYears'
    description: 'The maximum validity of an AAD Object credential in years'
    value: 2
  }
  {
    name: 'AzureOptimization_AADObjectsFilter'
    description: 'The Microsoft Entra object types to export'
    value: '"Application,ServicePrincipal,User,Group"'
  }
  {
    name: 'AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold'
    description: 'The percentage threshold (used to trigger recommendations) for total RBAC assignments limits'
    value: 80
  }
  {
    name: 'AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold'
    description: 'The percentage threshold (used to trigger recommendations) for resource group count limits'
    value: 80
  }
  {
    name: 'AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold'
    description: 'The percentage threshold (used to trigger recommendations) for maximum subnet address space usage'
    value: 80
  }
  {
    name: 'AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold'
    description: 'The percentage threshold (used to trigger recommendations) for minimum subnet address space usage'
    value: 5
  }
  {
    name: 'AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays'
    description: 'The minimum age (in days) for an empty subnet to trigger an NSG rule recommendation'
    value: 30
  }
  {
    name: 'AzureOptimization_RecommendationsMaxAgeInDays'
    description: 'The maximum age (in days) for a recommendation to be kept in the SQL database'
    value: 365
  }
  {
    name: 'AzureOptimization_RecommendationStorageAcountGrowthThresholdPercentage'
    description: 'The minimum Storage Account growth percentage required to flag Storage as not having a retention policy in place'
    value: 5
  }
  {
    name: 'AzureOptimization_RecommendationStorageAcountGrowthMonthlyCostThreshold'
    description: 'The minimum monthly cost (in your EA/MCA currency) required to flag Storage as not having a retention policy in place'
    value: 50
  }
  {
    name: 'AzureOptimization_RecommendationStorageAcountGrowthLookbackDays'
    description: 'The lookback period (in days) for analyzing Storage Account growth'
    value: 30
  }
]

//------------------------------------------------------------------------------
// Telemetry
// Used to anonymously count the number of times the template has been deployed
// and to track and fix deployment bugs to ensure the highest quality.
// No information about you or your cost data is collected.
//------------------------------------------------------------------------------

resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, projectLocation)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FinOps toolkit'
          version: finOpsToolkitVersion
        }
      }
      resources: []
    }
  }
}

resource logAnalyticsWorkspace 'microsoft.operationalinsights/workspaces@2020-08-01' = if (!logAnalyticsReuse) {
  name: logAnalyticsWorkspaceName
  location: projectLocation
  tags: resourceTags
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: logAnalyticsRetentionDays
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: projectLocation
  tags: resourceTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          enabled: true
        }
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Cool'
  }
}

resource storageBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource storageCsvExportsContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for item in csvExports: {
  name: '${storageAccountName}/default/${item.containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageBlobServices
    storageAccount
  ]
}]

resource storageRecommendationsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccountName}/default/${recommendationsContainerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageBlobServices
    storageAccount
  ]
}

resource storageRemediationLogsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccountName}/default/${remediationLogsContainerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageBlobServices
    storageAccount
  ]
}

resource storageLifecycleManagementPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2021-02-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'Clean6MonthsOldBlobs'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 180
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 180
                }
              }
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 180
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
        }
      ]
    }
  }
  dependsOn: [
    storageBlobServices
  ]
}

resource existingSqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = if (sqlServerAlreadyExists) {
  name: sqlServerName
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = if (!sqlServerAlreadyExists) {
  name: sqlServerName
  location: projectLocation
  tags: resourceTags
  properties: {
    version: '12.0'
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: userPrincipalName
      principalType: sqlAdminPrincipalType
      sid: userObjectId
      tenantId: tenant().tenantId
    }
  }
}

resource sqlAdminsResource 'Microsoft.Sql/servers/administrators@2022-05-01-preview' = if (sqlServerAlreadyExists) {
  parent: existingSqlServer
  name: 'ActiveDirectory'
  properties: {
        administratorType: 'ActiveDirectory'
        login: userPrincipalName 
        sid: userObjectId
        tenantId: tenant().tenantId
    }
}

resource sqlAzureAdOnly 'Microsoft.Sql/servers/azureADOnlyAuthentications@2022-05-01-preview' = if (sqlServerAlreadyExists) {
  name: 'Default'
  parent: existingSqlServer
  properties: {
    azureADOnlyAuthentication: true
  }
  dependsOn:[sqlAdminsResource]
}

resource sqlServerFirewall 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: projectLocation
  tags: resourceTags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: 60
    requestedBackupStorageRedundancy: 'Geo'
  }
}

resource sqlServerName_sqlDatabaseName_default 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2022-05-01-preview' = {
  name: '${sqlServerName}/${sqlDatabaseName}/default'
  properties: {
    retentionDays: sqlBackupRetentionDays
  }
  dependsOn: [
    sqlDatabase
    sqlServer
  ]
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName
  location: projectLocation
  tags: resourceTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

resource automationModule_Az_Accounts 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: automationAccount
  name: Az_Accounts.name
  tags: resourceTags
  properties: {
    contentLink: {
      uri: Az_Accounts.url
    }
  }
}

resource automationModule_Microsoft_Graph_Authentication 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: automationAccount
  name: Microsoft_Graph_Authentication.name
  tags: resourceTags
  properties: {
    contentLink: {
      uri: Microsoft_Graph_Authentication.url
    }
  }
}

resource automationModule_All 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = [for item in psModules: {
  parent: automationAccount  
  name: item.name
  tags: resourceTags
  properties: {
    contentLink: {
      uri: item.url
    }
  }
  dependsOn: [
    automationModule_Az_Accounts
    automationModule_Microsoft_Graph_Authentication
  ]
}]

resource automationRunbooks 'Microsoft.Automation/automationAccounts/runbooks@2020-01-13-preview' = [for item in runbooks: {
  parent: automationAccount  
  name: item.name
  tags: resourceTags
  location: projectLocation
  properties: {
    runbookType: item.type
    logProgress: false
    logVerbose: false
    description: item.description
    publishContentLink: {
      uri: item.scriptUri
      version: item.version
    }
  }
  dependsOn: [
    automationModule_All
  ]
}]

resource automationVariablesAll 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = [for item in automationVariables: {
  parent: automationAccount  
  name: item.name
  properties: {
    description: item.description
    value: item.value
  }
}]

resource automationVariables_csvExports 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = [for item in csvExports: {
  parent: automationAccount  
  name: item.variableName
  properties: {
    description: item.variableDescription
    value: '"${item.containerName}"'
  }
}]

resource automationVariables_SQLServerHostname 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: automationAccount  
  name: 'AzureOptimization_SQLServerHostname'
  properties: {
    description: 'The Azure SQL Server hostname for the ingestion control and recommendations tables'
    value: '"${sqlServer.properties.fullyQualifiedDomainName}"'
  }
}

resource automationVariables_LogAnalyticsWorkspaceId 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: automationAccount  
  name: 'AzureOptimization_LogAnalyticsWorkspaceId'
  properties: {
    description: 'The Log Analytics Workspace ID where optimization data will be ingested'
    value: '"${reference(((!logAnalyticsReuse) ? logAnalyticsWorkspace.id : resourceId(logAnalyticsWorkspaceRG, 'microsoft.operationalinsights/workspaces', logAnalyticsWorkspaceName)), '2020-08-01').customerId}"'
  }
}

resource automationVariables_LogAnalyticsWorkspaceKey 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: automationAccount  
  name: 'AzureOptimization_LogAnalyticsWorkspaceKey'
  properties: {
    description: 'The shared key for the Log Analytics Workspace where optimization data will be ingested'
    value: '"${listKeys(((!logAnalyticsReuse) ? logAnalyticsWorkspace.id : resourceId(logAnalyticsWorkspaceRG, 'microsoft.operationalinsights/workspaces', logAnalyticsWorkspaceName)), '2020-08-01').primarySharedKey}"'
    isEncrypted: true
  }
}

resource automationSchedules_csvExports 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = [for item in csvExportsSchedules: {
  parent: automationAccount
  name: item.exportSchedule
  properties: {
    description: item.exportDescription
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, item.exportTimeOffset)
    interval: 1
    frequency: item.exportFrequency
  }
}]

resource automationSchedules_csvIngests 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = [for item in csvExports: {
  parent: automationAccount
  name: item.ingestSchedule
  properties: {
    description: item.ingestDescription
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, item.ingestTimeOffset)
    interval: 1
    frequency: item.ingestFrequency
  }
}]

resource automationSchedules_remediationCsvIngest 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: remediationLogsIngestScheduleName
  properties: {
    description: 'Starts the daily Remediation Logs ingests'
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, 'PT1H30M')
    interval: 1
    frequency: 'Day'
  }
}

resource automationSchedules_recommendationsExport 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsScheduleName
  properties: {
    description: 'Starts the weekly Recommendations generation'
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, 'PT2H30M')
    interval: 1
    frequency: 'Week'
  }
}

resource automationSchedules_recommendationsIngest 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsIngestScheduleName
  properties: {
    description: 'Starts the weekly Recommendations ingests'
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, 'PT3H30M')
    interval: 1
    frequency: 'Week'
  }
}

resource automationSchedules_suppressionsIngest 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: suppressionsIngestScheduleName
  properties: {
    description: 'Starts the weekly Suppressions ingests'
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, 'PT3H00M')
    interval: 1
    frequency: 'Week'
  }
}

resource automationSchedules_recommendationsCleanUp 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsCleanUpScheduleName
  properties: {
    description: 'Starts the weekly Recommendations cleanup'
    expiryTime: '9999-12-31T17:59:00-06:00'
    startTime: dateTimeAdd(baseTime, 'P6D')
    interval: 1
    frequency: 'Week'
  }
}

resource automationJobSchedules_csvExports 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = [for item in csvExports: if (!item.isOneToMany) {
  parent: automationAccount
  name: item.exportJobId
  properties: {
    schedule: {
      name: item.exportSchedule
    }
    runbook: {
      name: item.runbookName
    }
  }
  dependsOn: [
    automationSchedules_csvExports
    automationModule_All
    automationRunbooks
  ]
}]

resource automationJobSchedules_csvParameterizedExports 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = [for item in csvParameterizedExports: {
  parent: automationAccount
  name: item.exportJobId
  properties: {
    schedule: {
      name: item.exportSchedule
    }
    runbook: {
      name: item.runbookName
    }
    parameters: item.parameters
  }
  dependsOn: [
    automationSchedules_csvExports
    automationModule_All
    automationRunbooks
  ]
}]

resource automationJobSchedules_csvIngests 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = [for item in csvExports: {
  parent: automationAccount
  name: item.ingestJobId
  properties: {
    schedule: {
      name: item.ingestSchedule
    }
    runbook: {
      name: csvIngestRunbookName
    }
    parameters: {
      StorageSinkContainer: item.containerName
    }
  }
  dependsOn: [
    automationSchedules_csvIngests
    automationModule_All
    automationRunbooks
  ]
}]

resource automationJobSchedules_remediationLogsIngests 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: remediationLogsIngestJobId
  properties: {
    schedule: {
      name: remediationLogsIngestScheduleName
    }
    runbook: {
      name: csvIngestRunbookName
    }
    parameters: {
      StorageSinkContainer: remediationLogsContainerName
    }
  }
  dependsOn: [
    automationSchedules_remediationCsvIngest
    automationModule_All
    automationRunbooks
  ]
}

resource automationJobSchedules_recommendationsExports 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = [for item in recommendations: {
  parent: automationAccount
  name: item.recommendationJobId
  properties: {
    schedule: {
      name: recommendationsScheduleName
    }
    runbook: {
      name: item.runbookName
    }
  }
  dependsOn: [
    automationSchedules_recommendationsExport
    automationModule_All
    automationRunbooks
  ]
}]

resource automationJobSchedules_recommendationsIngests 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsIngestJobId
  properties: {
    schedule: {
      name: recommendationsIngestScheduleName
    }
    runbook: {
      name: recommendationsIngestRunbookName
    }
  }
  dependsOn: [
    automationSchedules_recommendationsIngest
    automationModule_All
    automationRunbooks
  ]
}

resource automationJobSchedules_recommendationsLogAnalyticsIngest 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsLogAnalyticsIngestJobId
  properties: {
    schedule: {
      name: recommendationsIngestScheduleName
    }
    runbook: {
      name: recommendationsLogAnalyticsIngestRunbookName
    }
  }
  dependsOn: [
    automationSchedules_recommendationsIngest
    automationModule_All
    automationRunbooks
  ]
}

resource automationJobSchedules_suppressionsLogAnalyticsIngest 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: suppressionsLogAnalyticsIngestJobId
  properties: {
    schedule: {
      name: suppressionsIngestScheduleName
    }
    runbook: {
      name: suppressionsLogAnalyticsIngestRunbookName
    }
  }
  dependsOn: [
    automationSchedules_suppressionsIngest
    automationModule_All
    automationRunbooks
  ]
}

resource automationJobSchedules_recommendationsCleanUp 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  name: recommendationsCleanUpJobId
  properties: {
    schedule: {
      name: recommendationsCleanUpScheduleName
    }
    runbook: {
      name: cleanUpOlderRecommendationsRunbookName
    }
  }
  dependsOn: [
    automationSchedules_recommendationsCleanUp
    automationModule_All
    automationRunbooks
  ]
}

resource contributorRoleAssignmentGuid_resource 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: contributorRoleAssignmentGuid
  properties: {
    roleDefinitionId: roleContributor
    principalId: reference(automationAccount.id, '2019-06-01', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output automationPrincipalId string = reference(automationAccount.id, '2019-06-01', 'Full').identity.principalId
