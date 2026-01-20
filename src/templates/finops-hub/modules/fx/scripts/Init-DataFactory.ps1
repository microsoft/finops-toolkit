# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [string] $DataFactoryResourceGroup,
    [string] $DataFactoryName,
    [string] $Pipelines = "",
    [switch] $StartTriggers,
    [switch] $StopTriggers
)

# Init outputs
$DeploymentScriptOutputs = @{}

$RunPipelines = -not [string]::IsNullOrWhiteSpace($Pipelines)

if ($StartTriggers -or $RunPipelines)
{
    Start-Sleep -Seconds 10
}

if ($StartTriggers -or $StopTriggers)
{
    # Loop thru triggers
    $triggers = Get-AzDataFactoryV2Trigger `
        -ResourceGroupName $DataFactoryResourceGroup `
        -DataFactoryName $DataFactoryName
    
    Write-Output "Found $($triggers.Length) trigger(s)"
    Write-Output "StartTriggers: $StartTriggers"

    $triggers | ForEach-Object {
        $trigger = $_.Name
        if ($StopTriggers)
        {
            Write-Output "Stopping trigger $trigger..."
            $triggerOutput = Stop-AzDataFactoryV2Trigger `
                -ResourceGroupName $DataFactoryResourceGroup `
                -DataFactoryName $DataFactoryName `
                -Name $trigger `
                -Force `
                -ErrorAction SilentlyContinue # Ignore errors, since the trigger may not exist
        }
        else
        {
            Write-Output "Starting trigger $trigger..."
            $triggerOutput = Start-AzDataFactoryV2Trigger `
                -ResourceGroupName $DataFactoryResourceGroup `
                -DataFactoryName $DataFactoryName `
                -Name $trigger `
                -Force
        }
        if ($triggerOutput)
        {
            Write-Output "done..."
        }
        else
        {
            Write-Output "failed..."
        }
        $DeploymentScriptOutputs[$trigger] = $triggerOutput
    }

    if ($StopTriggers)
    {
        Start-Sleep -Seconds 10
    }
}

if ($RunPipelines)
{
    $Pipelines.Split('|') `
    | ForEach-Object {
        Write-Output "Running the init pipeline..."
        Invoke-AzDataFactoryV2Pipeline `
            -ResourceGroupName $DataFactoryResourceGroup `
            -DataFactoryName $DataFactoryName `
            -PipelineName $_
    }
}
