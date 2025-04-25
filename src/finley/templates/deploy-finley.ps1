[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName="ftk-finley",

    [Parameter()]
    [string]    
    $Location = 'WestUS3'
)

$rg = Get-AzResourceGroup -name $ResourceGroupName -ErrorAction SilentlyContinue
if($null -eq $rg) {
    New-AzResourceGroup -name $ResourceGroupName -Location $Location -Force
}
else{
    $Location = $rg.$Location
}


New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile ./main.bicep