# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [string] $DataFactoryResourceGroup,
    [string] $DataFactoryName,
    [string] $Pipelines = "",
    [switch] $StartTriggers,
    [switch] $StopTriggers
)

$MAX_RETRIES = 20
$DeploymentScriptOutputs = @{}

function Write-Log($Message)
{
    Write-Output "$(Get-Date -Format 'HH:mm:ss') $Message"
}

function Invoke-WithRetry([scriptblock]$Action, [string]$Name, [int]$Delay = 5)
{
    for ($i = 1; $i -le $MAX_RETRIES; $i++)
    {
        try { return & $Action }
        catch
        {
            Write-Log "$Name failed (attempt $i/${MAX_RETRIES}): $($_.Exception.Message)"
            if ($i -eq $MAX_RETRIES) { throw }
            Start-Sleep -Seconds ($Delay * $i) # Exponential backoff
        }
    }
}

function Set-BlobTriggerSubscription([string]$TriggerName, [switch]$Subscribe)
{
    $targetStatus = if ($Subscribe) { 'Enabled' } else { 'Disabled' }
    $action = if ($Subscribe) { 'Subscribing' } else { 'Unsubscribing' }

    Write-Log "$action $TriggerName to events..."
    Invoke-WithRetry -Name "$action $TriggerName" -Delay 5 -Action {
        if ($Subscribe)
        {
            Add-AzDataFactoryV2TriggerSubscription `
                -ResourceGroupName $DataFactoryResourceGroup `
                -DataFactoryName $DataFactoryName `
                -Name $TriggerName | Out-Null
        }
        else
        {
            Remove-AzDataFactoryV2TriggerSubscription `
                -ResourceGroupName $DataFactoryResourceGroup `
                -DataFactoryName $DataFactoryName `
                -Name $TriggerName | Out-Null
        }

        $status = Get-AzDataFactoryV2TriggerSubscriptionStatus `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
            -Name $TriggerName
        if ($status.Status -ne $targetStatus)
        {
            throw "Subscription status is $($status.Status), expected $targetStatus"
        }
    }
}

if ($StartTriggers -or $StopTriggers)
{
    $triggers = Invoke-WithRetry -Name "Get triggers" -Action {
        Get-AzDataFactoryV2Trigger `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
        | Where-Object {
            ($StartTriggers -and $_.Properties.RuntimeState -ne "Started") `
                -or ($StopTriggers -and $_.Properties.RuntimeState -ne "Stopped")
        }
    }

    Write-Log "Found $($triggers.Count) trigger(s) to $(if ($StartTriggers) { 'start' } else { 'stop' })"

    $triggers | ForEach-Object {
        $triggerName = $_.Name
        $isBlobTrigger = $null -ne $_.Properties.BlobPathBeginsWith

        if ($StopTriggers)
        {
            if ($isBlobTrigger) { Set-BlobTriggerSubscription -TriggerName $triggerName }
            Write-Log "Stopping trigger $triggerName..."
            Invoke-WithRetry -Name "Stop $triggerName" -Action {
                Stop-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $triggerName -Force
            }
        }
        else
        {
            if ($isBlobTrigger) { Set-BlobTriggerSubscription -TriggerName $triggerName -Subscribe }
            Write-Log "Starting trigger $triggerName..."
            Invoke-WithRetry -Name "Start $triggerName" -Action {
                Start-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $triggerName -Force
            }
        }

        Invoke-WithRetry -Name "Wait for $triggerName" -Action {
            $state = (Get-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $triggerName).Properties.RuntimeState
            $expected = if ($StartTriggers) { 'Started' } else { 'Stopped' }
            if ($state -ne $expected) { throw "Trigger is $state, expected $expected" }
        }

        Write-Log "...done"
        $DeploymentScriptOutputs[$triggerName] = $true
    }
}

if (-not [string]::IsNullOrWhiteSpace($Pipelines))
{
    $Pipelines.Split('|') | ForEach-Object {
        Write-Log "Running pipeline $_..."
        Invoke-AzDataFactoryV2Pipeline `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
            -PipelineName $_
    }
}
