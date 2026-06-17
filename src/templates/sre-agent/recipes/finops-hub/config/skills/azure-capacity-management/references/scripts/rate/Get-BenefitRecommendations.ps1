
<#
.SYNOPSIS
    Get Azure Cost Management benefit recommendations for savings plans and reserved instances.

.DESCRIPTION
    This script queries the Azure Cost Management API to retrieve benefit recommendations
    based on historical usage patterns. It helps identify opportunities for cost savings
    through Azure savings plans and reserved instances.

.PARAMETER BillingScope
    The billing scope to query. Can be a billing account or subscription.
    Examples:
    - "providers/Microsoft.Billing/billingAccounts/12345678"
    - "subscriptions/12345678-1234-1234-1234-123456789012"

.PARAMETER LookBackPeriod
    Historical period to analyze for recommendations.
    Valid values: Last7Days, Last30Days, Last60Days
    Default: Last7Days

.PARAMETER Term
    Commitment term for savings plans.
    Valid values: P1Y (1 year), P3Y (3 years)
    Default: P3Y

.EXAMPLE
    .\Get-BenefitRecommendations.ps1 -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012"
    
    Gets 3-year savings plan recommendations for a subscription based on last 7 days usage.

.EXAMPLE
    .\Get-BenefitRecommendations.ps1 -BillingScope "providers/Microsoft.Billing/billingAccounts/12345678" -LookBackPeriod "Last30Days" -Term "P1Y"
    
    Gets 1-year savings plan recommendations for a billing account based on last 30 days usage.

.NOTES
    Requires Azure PowerShell module and Cost Management Reader permissions on the specified scope.
    
    To find your billing account: Get-AzBillingAccount
    To find subscriptions: Get-AzSubscription
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Billing scope (billing account or subscription)")]
    [string]
    $BillingScope,

    [Parameter()]
    [ValidateSet('Last7Days', 'Last30Days', 'Last60Days')]
    [string]
    $LookBackPeriod = 'Last7Days',

    [Parameter()]
    [ValidateSet('P1Y', 'P3Y')]
    [string]
    $Term = 'P3Y'
)

$url="https://management.azure.com/{0}/providers/Microsoft.CostManagement/benefitRecommendations?`$filter=properties/lookBackPeriod eq '{1}' AND properties/term eq '{2}'&`$expand=properties/usage,properties/allRecommendationDetails&api-version=2024-08-01" -f $BillingScope, $lookBackPeriod, $term
$uri=[uri]::new($url)
$result = Invoke-AzRestMethod -Uri $uri.AbsoluteUri -Method GET
$jsonResult = $result.Content | ConvertFrom-Json

Write-Output ""
Write-Output "Raw output"
$result.Content
Write-Output ""
Write-Output "Recommended savings plan"
$jsonResult.value.properties.recommendationDetails | Format-Table
Write-Output ""
Write-Output "All savings plan recommendations"
$jsonResult.value.properties.allRecommendationDetails.value | Format-Table