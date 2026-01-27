# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [string] $DataFactoryResourceGroup,
    [string] $DataFactoryName,
    [string] $Pipelines = "",
    [switch] $StartTriggers,
    [switch] $StopTriggers
)

# Constants
$MAX_RETRIES = 20
$RETRY_DELAY_SECONDS = 1

# Init outputs
$DeploymentScriptOutputs = @{}

$RunPipelines = -not [string]::IsNullOrWhiteSpace($Pipelines)

# Helper function to write output with a timestamp
function Write-Log($Message)
{
    Write-Output "$(Get-Date -Format 'HH:mm:ss') $Message"
}

# Helper function to invoke an action with retry logic
function Invoke-WithRetry
{
    param(
        [scriptblock] $Action,
        [string] $ActionName,
        [switch] $SuppressErrors
    )

    $lastError = $null
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'

    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++)
    {
        try
        {
            $result = & $Action
            $ErrorActionPreference = $previousErrorAction
            return $result
        }
        catch
        {
            $lastError = $_
            Write-Log "$ActionName failed (attempt $attempt/${MAX_RETRIES}): $($_.Exception.Message)"
            if ($attempt -lt $MAX_RETRIES)
            {
                Start-Sleep -Seconds $RETRY_DELAY_SECONDS
            }
        }
    }

    # Report failure
    $ErrorActionPreference = $previousErrorAction
    if ($SuppressErrors)
    {
        Write-Log "$ActionName failed after $MAX_RETRIES attempts"
        return $null
    }
    else
    {
        throw $lastError
    }
}

if ($StartTriggers -or $StopTriggers)
{
    # Loop thru triggers
    $triggers = Invoke-WithRetry -ActionName "Get triggers" -Action {
        Get-AzDataFactoryV2Trigger `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
        | Where-Object {
            ($StartTriggers -and $_.properties.runtimeState -ne "Started") `
                -or ($StopTriggers -and $_.properties.runtimeState -ne "Stopped")
        }
    }

    Write-Log "Found $($triggers.Length) trigger(s)"
    Write-Log "StartTriggers: $StartTriggers"

    $triggers | ForEach-Object {
        $trigger = $_.Name
        if ($StopTriggers)
        {
            Write-Log "Stopping trigger $trigger..."
            $triggerOutput = Invoke-WithRetry -ActionName "Stop trigger $trigger" -SuppressErrors -Action {
                Stop-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $trigger `
                    -Force
            }
        }
        else
        {
            Write-Log "Starting trigger $trigger..."
            $triggerOutput = Invoke-WithRetry -ActionName "Start trigger $trigger" -SuppressErrors -Action {
                Start-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $trigger `
                    -Force
            }
        }
        if ($triggerOutput)
        {
            Write-Log "...done"
        }
        else
        {
            Write-Log "...failed"
        }
        $DeploymentScriptOutputs[$trigger] = $triggerOutput
    }

    # Wait for triggers to reach the desired state
    $triggers | ForEach-Object {
        $trigger = $_.Name
        Invoke-WithRetry -ActionName "Wait for trigger $trigger to update" -SuppressErrors -Action {
            $state = (Get-AzDataFactoryV2Trigger `
                    -ResourceGroupName $DataFactoryResourceGroup `
                    -DataFactoryName $DataFactoryName `
                    -Name $trigger).Properties.RuntimeState
            if (($StartTriggers -and $state -ne "Started") -or ($StopTriggers -and $state -ne "Stopped"))
            {
                throw "Trigger $trigger is still $state"
            }
        }
    }
}

if ($RunPipelines)
{
    $Pipelines.Split('|') `
    | ForEach-Object {
        $pipelineName = $_
        Write-Log "Running pipeline $pipelineName..."
        Invoke-AzDataFactoryV2Pipeline `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
            -PipelineName $pipelineName
    }
}
