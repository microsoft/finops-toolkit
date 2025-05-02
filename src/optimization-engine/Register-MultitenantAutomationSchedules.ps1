<#
.SYNOPSIS
This script adds job schedules for all Azure Optimization Engine data collection runbooks for a given tenant/cloud.

.DESCRIPTION
This script adds job schedules for all Azure Optimization Engine data collection runbooks for a given tenant/cloud.
It is useful when you want to collect data from multiple tenants/clouds in a single AOE deployment.
The script will create new schedules with a suffix and offset for each existing schedule, and associate them to the corresponding runbooks.
It requires you to create first a service principal in the target tenant and grant it the necessary permissions to the target subscriptions/tenant.
You also need to create an Automation Credential in the AOE Automation Account with the service principal credentials (client ID and secret).

.PARAMETER AzureEnvironment
The Azure environment to use. Possible values are AzureCloud, AzureChinaCloud, AzureUSGovernment.

.PARAMETER AutomationAccountName
The name of the Automation Account where the Azure Optimization Engine is deployed.

.PARAMETER ResourceGroupName
The name of the Resource Group where the Automation Account is located.

.PARAMETER TargetSchedulesSuffix
The suffix to append to the new schedules names.

.PARAMETER TargetSchedulesOffsetMinutes
The offset in minutes to apply to the new schedules start times (defaults to 0).

.PARAMETER TargetAzureEnvironment
The target Azure environment to collect data from. Possible values are AzureCloud, AzureChinaCloud, AzureUSGovernment. Defaults to AzureCloud.

.PARAMETER TargetTenantId
The target tenant ID to collect data from.

.PARAMETER TargetTenantCredentialName
The name of the Automation Credential in the AOE Automation Account containing the service principal credentials (client ID and secret).

.PARAMETER ExcludedRunbooks
An array of runbook names to exclude from the process. Defaults to runbooks that export data at the EA/MCA level, which should only run on the source tenant.

.PARAMETER IncludedRunbooks
An array of runbook names to include in the process. If none are provided, all data collection runbooks will be processed.

.EXAMPLE
Register-MultitenantAutomationSchedules.ps1 -AutomationAccountName "AOE" -ResourceGroupName "AOE-RG" -TargetSchedulesSuffix "-Tenant1" -TargetTenantId "00000000-0000-0000-0000-000000000000" -TargetTenantCredentialName "Tenant1" -ExcludedRunbooks @("Export-ReservationsPriceToBlobStorage")

.LINK
https://aka.ms/AzureOptimizationEngine/customize
#>
param(
    [Parameter(Mandatory = $false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $true)]
    [String] $AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [String] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [String] $TargetSchedulesSuffix,

    [Parameter(Mandatory = $false)]
    [int] $TargetSchedulesOffsetMinutes = 0,

    [Parameter(Mandatory = $false)]
    [String] $TargetAzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $true)]
    [String] $TargetTenantId,

    [Parameter(Mandatory = $true)]
    [String] $TargetTenantCredentialName,

    [Parameter(Mandatory = $false)]
    [String[]] $ExcludedRunbooks = @("Export-ReservationsPriceToBlobStorage","Export-PriceSheetToBlobStorage","Export-ReservationsUsageToBlobStorage","Export-SavingsPlansUsageToBlobStorage"),

    [Parameter(Mandatory = $false)]
    [String[]] $IncludedRunbooks = @()
)

$ErrorActionPreference = "Stop"

$ctx = Get-AzContext
if (-not($ctx)) {
    Connect-AzAccount -Environment $AzureEnvironment
    $ctx = Get-AzContext
}
else {
    if ($ctx.Environment.Name -ne $AzureEnvironment) {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $AzureEnvironment
        $ctx = Get-AzContext
    }
}

try
{
    $scheduledRunbooks = Get-AzAutomationScheduledRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName
}
catch
{
    throw "$AutomationAccountName Automation Account not found in Resource Group $ResourceGroupName in Subscription $($ctx.Subscription.Name). If we are not in the right subscription, use Set-AzContext to switch to the correct one."
}

$dataCollectionRunbooks = $scheduledRunbooks | Where-Object { $_.RunbookName -like "Export-*" -and $_.RunbookName -notin $ExcludedRunbooks -and $_.RunbookName -ne "Export-ReservationsPriceToBlobStorage" }
if ($IncludedRunbooks.Count -gt 0)
{
    $dataCollectionRunbooks = $dataCollectionRunbooks | Where-Object { $_.RunbookName -in $IncludedRunbooks }
}

if (-not($dataCollectionRunbooks))
{
    throw "The $AutomationAccountName Automation Account does not contain any scheduled data collection runbook. It might not be associated to the Azure Optimization Engine."
}

foreach ($jobSchedule in $dataCollectionRunbooks)
{
    Write-Host "Processing $($jobSchedule.RunbookName) runbook for $($jobSchedule.ScheduleName) schedule..." -ForegroundColor Green
    $schedule = Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ScheduleName $jobSchedule.ScheduleName
    $newScheduleName = "$($schedule.Name)$TargetSchedulesSuffix"
    $newSchedule = Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
        -ScheduleName $newScheduleName -ErrorAction SilentlyContinue
    if (-not($newSchedule))
    {
        Write-Host "Creating new schedule $newScheduleName..." -ForegroundColor Green
        $newScheduleParameters = @{
            ResourceGroupName = $ResourceGroupName;
            AutomationAccountName = $AutomationAccountName;
            Name = $newScheduleName;
            StartTime = $schedule.NextRun.AddMinutes($TargetSchedulesOffsetMinutes);
            ExpiryTime = $schedule.ExpiryTime;
            Timezone = $schedule.TimeZone
        }
        switch ($schedule.Frequency)
        {
            "Hour" {
                $newScheduleParameters['HourInterval'] = $schedule.Interval
            }
            "Day" {
                $newScheduleParameters['DayInterval'] = $schedule.Interval
            }
            "Week" {
                $newScheduleParameters['WeekInterval'] = $schedule.Interval
                $newScheduleParameters['DaysOfWeek'] = $schedule.WeeklyScheduleOptions.DaysOfWeek
            }
            default {
                throw "Unsupported frequency: $($schedule.Frequency)"
            }
        }
        New-AzAutomationSchedule @newScheduleParameters | Out-Null
    }

    Write-Host "Associating schedule $newScheduleName to $($jobSchedule.RunbookName) runbook..." -ForegroundColor Green
    $jobScheduleDetails = Get-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
        -JobScheduleId $jobSchedule.JobScheduleId
    $jobScheduleDetails.Parameters.Add("externalCloudEnvironment", $TargetAzureEnvironment)
    $jobScheduleDetails.Parameters.Add("externalTenantId", $TargetTenantId)
    $jobScheduleDetails.Parameters.Add("externalCredentialName", $TargetTenantCredentialName)
    $newJobScheduleParameters = @{
        ResourceGroupName = $ResourceGroupName;
        AutomationAccountName = $AutomationAccountName;
        RunbookName = $jobScheduleDetails.RunbookName;
        ScheduleName = $newScheduleName;
        RunOn = $jobScheduleDetails.HybridWorker;
        Parameters = $jobScheduleDetails.Parameters
    }
    Register-AzAutomationScheduledRunbook @newJobScheduleParameters | Out-Null
}

Write-Host "DONE" -ForegroundColor Green