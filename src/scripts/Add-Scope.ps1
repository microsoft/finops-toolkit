param(
  [string]$hubName,
  [string]$Scope,
  [string]$StorageAccountId,
  [int]$numberOfMonths = 2,
  [string]$ContainerName = "ms-cm-exports",
  [string]$FolderName = $Scope,
  [string]$Metric = "amortizedcost",
  [string][ValidateSet('AzureCloud', 'AzureUSGovernment')]$Cloud = 'AzureCloud',
  [int]$TimeOutMinutes = 15,
  [int]$SleepInterval = 10
)

$ErrorActionPreference = "Stop"
[bool]$SetRecurringExports = $true
[bool]$GetHistoricalData = $true
if($numberOfMonths -lt 2) {$GetHistoricalData = $false}
[datetime]$today = Get-Date
[datetime]$StartDate = $today.AddDays(-$today.Day + 1).AddMonths(-$numberOfMonths)
[datetime]$EndDate = $today.AddDays(-$today.Day + 1).AddMonths(-1).AddDays(-1)
$env = Get-AzEnvironment -Name $Cloud

if($FolderName.StartsWith('/')) {$FolderName = $FolderName.Substring(1)}
if(!$Scope.StartsWith('/')) {$Scope = '/' + $Scope}

function Write-DebugInfo {
  param (
    $DebugParams
  )

  Write-Host ("{0}    {1}    {2}" -f (Get-Date), $DebugParams.Name, $DebugParams.DefinitionTimeframe)
}

function Invoke-CostManagementRestApi {
  param (
    $ApiParams
  )

  $uri = "{0}{1}/providers/Microsoft.CostManagement/exports/{2}?api-version=2021-10-01" -f $env.ResourceManagerUrl, $ApiParams.Scope, $ApiParams.Name
  Remove-AzCostManagementExport -Name $ApiParams.Name -Scope $ApiParams.Scope -ErrorAction SilentlyContinue
  
  if ([string]$ApiParams.DefinitionTimeframe.ToLowerInvariant() -eq 'custom') {
    $payload = '{
      "properties": {
        "schedule": {
          "status": "Inactive",
          "recurrence": "daily",
          "recurrencePeriod": {
            "from": "2099-06-01T00:00:00Z",
            "to": "2099-10-31T00:00:00Z"
          }
        },
        "partitionData": "true",
        "format": "Csv",
        "deliveryInfo": {
          "destination": {
            "resourceId": "{0}",
            "container": "{1}",
            "rootFolderPath": "{2}"
          }
        },
        "definition": {
          "type": "{3}",
          "timeframe": "Custom",
          "timePeriod" : {
            "from" : "{4}",
            "to" : "{5}"
          },
          "dataSet": {
            "granularity": "Daily"
          }
        }
      }
    }'
  
    $payload = $payload.Replace("{0}", $ApiParams.DestinationResourceId)
    $payload = $payload.Replace("{1}", $ApiParams.DestinationContainer)
    $payload = $payload.Replace("{2}", $ApiParams.DestinationRootFolderPath)
    $payload = $payload.Replace("{3}", $ApiParams.DefinitionType)
    $payload = $payload.Replace("{4}", $ApiParams.TimePeriodFrom)
    $payload = $payload.Replace("{5}", $ApiParams.TimePeriodTo)
    $payload = $payload.Replace("{6}", $ApiParams.PartitionData)
  }
  else {
    $payload = '{
      "properties": {
        "schedule": {
          "status": "{8}",
          "recurrence": "{7}",
          "recurrencePeriod": {
            "from": "{6}",
            "to": "{9}"
          }
        },
        "partitionData": "{5}",
        "format": "Csv",
        "deliveryInfo": {
          "destination": {
            "resourceId": "{0}",
            "container": "{1}",
            "rootFolderPath": "{2}"
          }
        },
        "definition": {
          "type": "{3}",
          "timeframe": "{4}",
          "dataSet": {
            "granularity": "Daily"
          }
        }
      }
    }'

    $payload = $payload.Replace("{0}", $ApiParams.DestinationResourceId)
    $payload = $payload.Replace("{1}", $ApiParams.DestinationContainer)
    $payload = $payload.Replace("{2}", $ApiParams.DestinationRootFolderPath)
    $payload = $payload.Replace("{3}", $ApiParams.DefinitionType)
    $payload = $payload.Replace("{4}", $ApiParams.DefinitionTimeframe)
    $payload = $payload.Replace("{5}", $ApiParams.PartitionData)
    $payload = $payload.Replace("{6}", $ApiParams.RecurrencePeriodFrom)
    $payload = $payload.Replace("{9}", $ApiParams.RecurrencePeriodTo)
    $payload = $payload.Replace("{7}", $ApiParams.ScheduleRecurrence)
    $payload = $payload.Replace("{8}", $ApiParams.ScheduleStatus)
  }
  
  $apiResult = Invoke-AzRestMethod -Uri $uri -Method PUT -Payload $payload
  if ($apiResult.StatusCode -ne "201") {
    $apiResult
    Throw "Cost Management API call failed"
  }
}

function Set-CostManagementExport {
  param (
    $ExportParams,
    [bool]$Start = $false
  )

  Write-DebugInfo $ExportParams
  Invoke-CostManagementRestApi -ApiParams $ExportParams
  if ($Start) {
    Start-Sleep -Seconds $SleepInterval
    Invoke-AzCostManagementExecuteExport -ExportName $ExportParams.Name -Scope $ExportParams.Scope
    Start-Sleep -Seconds $SleepInterval
    $currentStatus = $null
    $currentStatus = (Get-AzCostManagementExport -Name $ExportParams.Name -Scope $ExportParams.Scope -Expand runHistory).RunHistory.Value[0].Status
    [int]$loop = 0
    while ($currentStatus -eq "InProgress") {
      if ($loop -ge $TimeOutMinutes) {
        $currentStatus = "TimedOut"
      }
      else {
        Start-Sleep -Seconds 60
        $loop++
        $currentStatus = (Get-AzCostManagementExport -Name $ExportParams.Name -Scope $ExportParams.Scope -Expand runHistory).RunHistory.Value[0].Status
        Write-Host ("{0}    {1}    {2}" -f (get-date), $ExportParams.Name, $currentStatus)
      }
    }

    Write-Host ("{0}    {1}    {2}" -f (get-date), $ExportParams.Name, $currentStatus)
  }
}

# Configure daily and monthly recurring exports
if ($SetRecurringExports) {
  Write-Host ("{0}    {1}" -f (get-date), "Set Recurring Exports")
  $today = Get-Date
  $nextMonth = $today.AddDays(-$today.Day + 5).AddMonths(1)
  [string]$dateFrom = "{0}-{1}-{2}T10:00:00Z" -f $nextMonth.Year, $nextMonth.Month, $nextMonth.Day

  # Last Billing Month
  $exportName = "{0}-{1}-c-{2}" -f $Metric, $Scope.Split('/')[$Scope.Split('/').Length - 1], $HubName
  $Params = @{
    Name                      = $exportName.substring(0, [System.Math]::Min(63, $exportName.Length))
    DefinitionType            = $Metric
    DataSetGranularity        = 'Daily'
    Scope                     = $Scope
    DestinationResourceId     = $StorageAccountId
    DestinationContainer      = $ContainerName
    DefinitionTimeframe       = 'TheLastBillingMonth'
    ScheduleRecurrence        = 'Monthly'
    RecurrencePeriodFrom      = $dateFrom
    RecurrencePeriodTo        = "2099-12-31T00:00:00Z"
    ScheduleStatus            = 'Active'
    DestinationRootFolderPath = $FolderName
    Format                    = 'Csv'
    PartitionData             = $true
  }
  Set-CostManagementExport -ExportParams $Params -Start $true

  # Billing Month To Date
  $tomorrow = (Get-Date).AddDays(1)
  [string]$dateFrom = "{0}-{1}-{2}T10:00:00Z" -f $tomorrow.Year, $tomorrow.Month, $tomorrow.Day
  $exportName = "{0}-{1}-o-{2}" -f $Metric, $Scope.Split('/')[$Scope.Split('/').Length - 1], $HubName
  $Params = @{
    Name                      = $exportName.substring(0, [System.Math]::Min(63, $exportName.Length))
    DefinitionType            = $Metric
    DataSetGranularity        = 'Daily'
    Scope                     = $Scope
    DestinationResourceId     = $StorageAccountId
    DestinationContainer      = $ContainerName
    DefinitionTimeframe       = 'BillingMonthToDate'
    ScheduleRecurrence        = 'Daily'
    RecurrencePeriodFrom      = $dateFrom
    RecurrencePeriodTo        = "2099-12-31T00:00:00Z"
    ScheduleStatus            = 'Active'
    DestinationRootFolderPath = $FolderName
    Format                    = 'Csv'
    PartitionData             = $true
  }
  Set-CostManagementExport -ExportParams $Params -Start $true  
}

# Export historical data
if ($GetHistoricalData) {
  Write-Host ("{0}    {1}" -f (get-date), "Historical Exports")

  [string]$dateFrom = "{0}-{1}-{2}T00:00:00Z" -f $StartDate.Year, $StartDate.Month, $StartDate.Day
  [string]$dateTo = "{0}-{1}-{2}T23:59:59Z" -f $EndDate.Year, $EndDate.Month, $EndDate.Day
  [datetime]$currentDate = $StartDate
  while ($currentDate -le $EndDate) {
    [datetime]$nextDate = $currentDate.AddDays(-$currentDate.Day + 1).AddMonths(1).AddDays(-1)
    [string]$dateFrom = "{0}-{1}-{2}T00:00:00Z" -f $currentDate.Year, $currentDate.Month, $currentDate.Day
    [string]$dateTo = "{0}-{1}-{2}T23:59:59Z" -f $nextDate.Year, $nextDate.Month, $nextDate.Day
    $exportName = "{0}-{1}-h-{2}" -f $Metric, $Scope.Split('/')[$Scope.Split('/').Length - 1], $HubName
    $Params = @{
      Name                      = $exportName.substring(0, [System.Math]::Min(63, $exportName.Length))
      DefinitionType            = $Metric
      DataSetGranularity        = 'Daily'
      Scope                     = $Scope
      DestinationResourceId     = $StorageAccountId
      DestinationContainer      = $ContainerName
      DefinitionTimeframe       = 'Custom'
      ScheduleRecurrence        = 'Daily'
      TimePeriodFrom            = $dateFrom
      TimePeriodTo              = $dateTo
      RecurrencePeriodFrom      = "2099-01-01T00:00:00Z"
      RecurrencePeriodTo        = "2099-12-31T00:00:00Z"
      ScheduleStatus            = 'Inactive'
      DestinationRootFolderPath = $FolderName
      Format                    = 'Csv'
      PartitionData             = $true
    }

    Set-CostManagementExport -ExportParams $Params -Start $true
    $currentDate = $currentDate.AddDays(-$currentDate.Day + 1).AddMonths(1)
  }
}