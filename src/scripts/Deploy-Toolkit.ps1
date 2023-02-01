Param(
    [string]$ResourceGroup,
    [string]$Location = "westus",
    [string]$Template = "finops-hub"
)

# Set default RG name to "ftk-<username>-<computername>"
If ([string]::IsNullOrEmpty($ResourceGroup)) {
    # For some reason, using variables directly does not get the value until we write them
    $c = $env:ComputerName
    $u = $env:USERNAME
    $c | Out-Null
    $u | Out-Null
    $ResourceGroup = "ftk-$u-$c".ToLower()
}

# Create resource group if it doesn't exist
$rg = Get-AzResourceGroup $ResourceGroup
If ($null -eq $rg) {
    New-AzResourceGroup `
        -Name $ResourceGroup `
        -Location $Location `
    | Out-Null
}

# Start deployment
$params = @{ hubName = $ResourceGroup };
New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroup `
    -TemplateFile "../templates/$Template/main.bicep" `
    -TemplateParameterObject $params
