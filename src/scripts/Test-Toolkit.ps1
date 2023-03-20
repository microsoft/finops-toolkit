param (
    [string]$ResourceGroup,
    [string][ValidateSet('Deploy', 'Test', 'Clean', 'Full')]$Mode = 'Full',
    [string[]]$ExportScopes = @("/providers/Microsoft.Billing/billingAccounts/8611537",
                                "subscriptions/64e355d7-997c-491d-b0c1-8414dccfcf42"),  # Test case to cater for scopes which don't start with '/'
    [switch]$WhatIf
)

Write-Host ("{0}    Mode = {1}" -f (Get-Date), $Mode)

If ([string]::IsNullOrEmpty($ResourceGroup)) {
    # For some reason, using variables directly does not get the value until we write them
    $c = $env:ComputerName
    $u = $env:USERNAME
    $c | Out-Null
    $u | Out-Null
    $ResourceGroup = "ftk-$u-$c".ToLower()
}

if ($Mode -eq 'Clean' -or $Mode -eq 'Full') {
    $rg = Get-AzResourceGroup -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if ($null -eq $rg) {
        Write-Host ("{0}    Resource Group Not Found" -f (Get-Date))
    }
    else {
        Write-Host ("{0}    Remove Existing Deployment" -f (Get-Date))
        $kv = Get-AzKeyVault -ResourceGroupName $ResourceGroup
        Remove-AzResourceGroup -Name $ResourceGroup -Force
        Remove-AzKeyVault -InRemovedState -VaultName $kv.VaultName -Force -Location $rg.Location
        # Get-AzKeyVault -InRemovedState | Remove-AzKeyVault -InRemovedState
    }

    Write-Host ("{0}    Cleanup Complete" -f (Get-Date))
}

$result = $null
if($Mode -eq 'Deploy' -or $Mode -eq 'Full') {
    $df = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    $sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if($null -ne $df -and $null -ne $sa) {
        Write-Host ("{0}    Stop Existing ADF Trigger" -f (Get-Date))
        Stop-AzDataFactoryV2Trigger `
            -ResourceGroupName $ResourceGroup `
            -DataFactoryName $df.DataFactoryName `
            -Name $sa.StorageAccountName -Force -ErrorAction SilentlyContinue | Out-Null
    }`
    
    Write-Host ("{0}    Start Deployment" -f (Get-Date))
    $result = .\Deploy-Toolkit.ps1 -ResourceGroup $ResourceGroup -exportScopes $ExportScopes -WhatIf:$WhatIf
    Write-Host ("{0}    Deployment Complete" -f (Get-Date))
    Write-Host ''
}

if ($Mode -eq 'Test' -or $Mode -eq 'Full') {
    Write-Host ("{0}    Start Test" -f (Get-Date))
    $sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    foreach ($exportScope in $ExportScopes)
    {
        if(!$exportScope.StartsWith('/')) {
            $exportScope = '/' + $exportScope
        }
        Write-Host ("{0}    Add Export Scope {1}" -f (Get-Date), $exportScope)
        .\Add-Scope.ps1 -hubName $ResourceGroup -StorageAccountId $sa.id -Scope $exportScope -TimeOutMinutes 0 -numberOfMonths 3
    }
    Write-Host ("{0}    Test Complete" -f (Get-Date))
    Write-Host ''
}

return $result