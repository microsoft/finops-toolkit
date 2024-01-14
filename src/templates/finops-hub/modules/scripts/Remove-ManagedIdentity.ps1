# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param
(
    [switch]
    $storage,

    [switch]
    $dataFactory
)

$maxRetries = 5
$retryInterval = 5 # seconds

for ($i = 1; $i -le $maxRetries; $i++)
{
    try
    {
        $shouldRemove = $false
        $removeParams = $null

        if ($dataFactory)
        {
            Write-Output "Has msexports trigger been started?"
            $trigger = Get-AzDataFactoryV2Trigger -DataFactoryName $env:dataFactoryName -ResourceGroupName $env:resourceGroupName -TriggerName msexports | Where-Object { $_.RuntimeState -eq "Started" }
            $shouldRemove = $trigger.RuntimeState -eq "Started"
            $removeParams = ${ ResourceName = $env:dataFactoryName }
            Write-Output $shouldRemove
            Write-Output ""
        }
        elseif ($storage)
        {
            Write-Output "Was settings.json deployed?"
            $ctx = New-AzStorageContext -StorageAccountName $env:storageAccountName -UseConnectedAccount
            $settingsFile = Get-AzStorageBlob -Container $env:containerName -Context $ctx -Blob settings.json
            $shouldRemove = $null -ne $settingsFile
            Write-Output $shouldRemove
            Write-Output ""
        }
    
        if ($shouldRemove)
        {
            Write-Output "Delete managed identity $env:managedIdentityName..."
            Remove-AzUserAssignedIdentity -Name $env:managedIdentityName -ResourceGroupName $env:resourceGroupName
            Write-Output "...done"
            Write-Output ""
            
            Write-Output "Delete role assignments for $env:managedIdentityName..."
            Get-AzRoleAssignment -ObjectId $env:managedIdentityName -ResourceGroupName $env:resourceGroupName @removeParams `
            | ForEach-Object {
                Write-Output "...deleting $($_.RoleDefinitionName)"
                Remove-AzRoleAssignment
            }
            Write-Output "...done"
            
            break
        }
        throw
    }
    catch
    {
        # Retry progressively longer each cycle
        $retryInSecs = $retryInterval * $i
        Write-Output "Operation failed: $_"
        Write-Output "Retrying in $retryInSecs seconds..."
        Write-Output ""
        Start-Sleep -Seconds $retryInSecs
    }
}

if ($i -gt $maxRetries)
{
    Write-Output "Operation failed after $maxRetries attempts."
}