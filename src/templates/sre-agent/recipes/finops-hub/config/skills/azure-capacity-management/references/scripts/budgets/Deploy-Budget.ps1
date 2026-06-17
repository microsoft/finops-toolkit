#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy budget configuration to an Azure subscription.

.DESCRIPTION
    This script deploys the budget Bicep template to create a subscription-level
    cost budget with notification thresholds. The script handles subscription
    validation, parameter collection, and deployment with proper error handling.

.PARAMETER SubscriptionId
    The target Azure subscription ID where the budget will be deployed.
    If not provided, the script will prompt for selection from available subscriptions.

.PARAMETER BudgetName
    Name of the budget. Defaults to 'SubscriptionBudget'.

.PARAMETER Amount
    The total budget amount in the billing currency. Defaults to 1000.

.PARAMETER TimeGrain
    Budget reset period: Monthly, Quarterly, or Annually. Defaults to Monthly.

.PARAMETER StartDate
    Budget start date in YYYY-MM-DD format. Must be first of month.
    Defaults to first of next month.

.PARAMETER EndDate
    Budget end date in YYYY-MM-DD format. Defaults to one year from start date.

.PARAMETER ContactEmails
    Array of email addresses that'll receive budget notifications.

.PARAMETER ContactRoles
    Array of Azure roles to notify. Defaults to Owner and Contributor.

.PARAMETER FirstThreshold
    First notification threshold percentage. Defaults to 50.

.PARAMETER SecondThreshold
    Second notification threshold percentage. Defaults to 75.

.PARAMETER ThirdThreshold
    Third notification threshold percentage. Defaults to 90.

.PARAMETER ForecastedThreshold
    Forecasted cost notification threshold percentage. Defaults to 100.

.PARAMETER DeploymentName
    Optional custom name for the deployment. If not provided, a timestamped name will be generated.

.PARAMETER Location
    Azure region for the deployment. Defaults to 'West US'.

.PARAMETER Force
    Skip confirmation prompts and proceed with deployment automatically.

.PARAMETER Quiet
    Suppress verbose deployment progress output.

.EXAMPLE
    ./Deploy-Budget.ps1 -ContactEmails @("admin@company.com") -Amount 5000

    Deploy budget with interactive subscription selection and $5000 monthly budget.

.EXAMPLE
    ./Deploy-Budget.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ContactEmails @("admin@company.com") -Amount 10000 -TimeGrain Quarterly -WhatIf

    Preview quarterly budget deployment without making changes.

.EXAMPLE
    ./Deploy-Budget.ps1 -ContactEmails @("admin@company.com") -Amount 2000 -Force

    Deploy without confirmation prompts.

.NOTES
    - Requires Azure PowerShell module (Az)
    - User must be authenticated to Azure (Connect-AzAccount)
    - User must have appropriate permissions to create subscription-level resources
    - Start date must be the first of the month
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$BudgetName = 'SubscriptionBudget',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Amount,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Monthly', 'Quarterly', 'Annually')]
    [string]$TimeGrain = 'Monthly',

    [Parameter(Mandatory = $false)]
    [string]$StartDate,

    [Parameter(Mandatory = $false)]
    [string]$EndDate,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ContactEmails,

    [Parameter(Mandatory = $false)]
    [string[]]$ContactRoles = @('Owner', 'Contributor'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$FirstThreshold = 50,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$SecondThreshold = 75,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$ThirdThreshold = 90,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$ForecastedThreshold = 100,

    [Parameter(Mandatory = $false)]
    [string]$DeploymentName,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'West US',

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colors = @{
        'Info' = 'White'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Success' = 'Green'
    }

    Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

function Get-SubscriptionSelection {
    param([string]$TargetSubscriptionId)

    try {
        $subscriptions = Get-AzSubscription | Sort-Object Name

        if ($subscriptions.Count -eq 0) {
            throw "No subscriptions found. Check if you are logged in with the correct Azure account."
        }

        if ($TargetSubscriptionId) {
            $selectedSub = $subscriptions | Where-Object { $_.Id -eq $TargetSubscriptionId }
            if (-not $selectedSub) {
                throw "Subscription with ID '$TargetSubscriptionId' not found or not accessible."
            }
            return $selectedSub
        }

        if ($subscriptions.Count -eq 1) {
            Write-Log "Using the only available subscription: $($subscriptions[0].Name)" -Level Info
            return $subscriptions[0]
        }

        Write-Log "Multiple subscriptions found. Please select:" -Level Info
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            Write-Host "  [$i] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
        }

        do {
            $selection = Read-Host "Enter subscription number [0-$($subscriptions.Count - 1)]"
            $selectionIndex = $null
            if ([int]::TryParse($selection, [ref]$selectionIndex) -and
                $selectionIndex -ge 0 -and $selectionIndex -lt $subscriptions.Count) {
                return $subscriptions[$selectionIndex]
            }
            Write-Log "Invalid selection. Please enter a number between 0 and $($subscriptions.Count - 1)." -Level Warning
        } while ($true)
    }
    catch {
        throw "Failed to get subscription information: $($_.Exception.Message)"
    }
}

function Get-DefaultStartDate {
    # Returns first of next month in YYYY-MM-DD format
    $today = Get-Date
    $nextMonth = $today.AddMonths(1)
    $firstOfMonth = Get-Date -Year $nextMonth.Year -Month $nextMonth.Month -Day 1
    return $firstOfMonth.ToString('yyyy-MM-dd')
}

function Get-DefaultEndDate {
    param([string]$StartDate)
    # Returns one year from start date
    $start = [DateTime]::Parse($StartDate)
    $end = $start.AddYears(1)
    return $end.ToString('yyyy-MM-dd')
}

function Confirm-Deployment {
    param(
        [object]$Subscription,
        [string]$BudgetName,
        [int]$Amount,
        [string]$TimeGrain,
        [string]$StartDate,
        [string]$EndDate,
        [string[]]$ContactEmails,
        [string]$DeploymentName
    )

    if ($Force) {
        return $true
    }

    Write-Host ""
    Write-Log "Deployment summary:" -Level Info
    Write-Host "  Subscription: $($Subscription.Name) ($($Subscription.Id))"
    Write-Host "  Budget name: $BudgetName"
    Write-Host "  Amount: $Amount ($TimeGrain)"
    Write-Host "  Period: $StartDate to $EndDate"
    Write-Host "  Email recipients: $($ContactEmails -join ', ')"
    Write-Host "  Deployment name: $DeploymentName"
    Write-Host ""

    $confirmation = Read-Host "Do you want to proceed with this deployment? (y/N)"
    return ($confirmation -eq 'y' -or $confirmation -eq 'Y')
}

#endregion

#region Main Script

try {
    Write-Log "Starting budget deployment script..." -Level Info

    # Check if Azure PowerShell is available
    if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
        throw "Azure PowerShell module (Az) isn't installed. Please install it using: Install-Module -Name Az"
    }

    # Check Azure connection
    if (-not (Test-AzureConnection)) {
        Write-Log "Not connected to Azure. Please run 'Connect-AzAccount' first." -Level Error
        throw "Azure authentication required"
    }

    Write-Log "Azure connection verified." -Level Success

    # Get target subscription
    $targetSubscription = Get-SubscriptionSelection -TargetSubscriptionId $SubscriptionId
    Write-Log "Selected subscription: $($targetSubscription.Name)" -Level Success

    # Set the subscription context
    $null = Set-AzContext -SubscriptionId $targetSubscription.Id

    # Determine budget amount: explicit parameter > BudgetAmount tag > default ($10)
    $defaultAmount = 10
    if ($PSBoundParameters.ContainsKey('Amount')) {
        Write-Log "Using explicitly provided amount: $Amount" -Level Info
    } else {
        # Check for BudgetAmount tag on subscription (must use Get-AzTag, not Get-AzSubscription)
        $tagValue = $null
        try {
            $subscriptionResourceId = "/subscriptions/$($targetSubscription.Id)"
            $tags = Get-AzTag -ResourceId $subscriptionResourceId -ErrorAction SilentlyContinue
            if ($tags -and $tags.Properties -and $tags.Properties.TagsProperty) {
                $tagValue = $tags.Properties.TagsProperty['BudgetAmount']
            }
        } catch {
            Write-Log "Could not retrieve subscription tags: $($_.Exception.Message)" -Level Warning
        }

        if ($tagValue) {
            $parsedAmount = 0
            if ([int]::TryParse($tagValue, [ref]$parsedAmount) -and $parsedAmount -gt 0) {
                $Amount = $parsedAmount
                Write-Log "Using BudgetAmount tag value: $Amount" -Level Info
            } else {
                Write-Log "Invalid BudgetAmount tag value '$tagValue', using default: $defaultAmount" -Level Warning
                $Amount = $defaultAmount
            }
        } else {
            $Amount = $defaultAmount
            Write-Log "No BudgetAmount tag found, using default: $Amount" -Level Info
        }
    }

    # Set default dates if not provided
    if (-not $StartDate) {
        $StartDate = Get-DefaultStartDate
        Write-Log "Using default start date: $StartDate" -Level Info
    }

    if (-not $EndDate) {
        $EndDate = Get-DefaultEndDate -StartDate $StartDate
        Write-Log "Using default end date: $EndDate" -Level Info
    }

    # Validate start date is first of month
    $startDateParsed = [DateTime]::Parse($StartDate)
    if ($startDateParsed.Day -ne 1) {
        throw "Start date must be the first of the month. Got: $StartDate"
    }

    # Generate deployment name if not provided
    if (-not $DeploymentName) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $DeploymentName = "budget-$timestamp"
    }

    # Get the script directory and template path
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $templateFile = Join-Path $scriptDir "budget.bicep"

    # Verify template file exists
    if (-not (Test-Path $templateFile)) {
        throw "Bicep template file not found: $templateFile"
    }

    Write-Log "Template file found: $templateFile" -Level Success

    # Validate email addresses
    $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    foreach ($email in $ContactEmails) {
        if ($email -notmatch $emailRegex) {
            throw "Invalid email address format: $email"
        }
    }

    Write-Log "Email addresses validated." -Level Success

    # Prepare deployment parameters
    $deploymentParams = @{
        budgetName = $BudgetName
        amount = $Amount
        timeGrain = $TimeGrain
        startDate = $StartDate
        endDate = $EndDate
        contactEmails = $ContactEmails
        contactRoles = $ContactRoles
        firstThreshold = $FirstThreshold
        secondThreshold = $SecondThreshold
        thirdThreshold = $ThirdThreshold
        forecastedThreshold = $ForecastedThreshold
    }

    # Show deployment summary and get confirmation
    if (-not (Confirm-Deployment -Subscription $targetSubscription -BudgetName $BudgetName -Amount $Amount -TimeGrain $TimeGrain -StartDate $StartDate -EndDate $EndDate -ContactEmails $ContactEmails -DeploymentName $DeploymentName)) {
        Write-Log "Deployment cancelled by user." -Level Warning
        return
    }

    # Prepare deployment splat
    $deploymentSplat = @{
        Name = $DeploymentName
        Location = $Location
        TemplateFile = $templateFile
        TemplateParameterObject = $deploymentParams
    }

    if ($WhatIfPreference) {
        Write-Log "Running deployment validation (What-If)..." -Level Info

        # Run What-If deployment preview
        if ($Quiet) {
            $whatIfResult = New-AzSubscriptionDeployment @deploymentSplat -WhatIf -WhatIfResultFormat FullResourcePayloads 2>&1
        } else {
            $whatIfResult = New-AzSubscriptionDeployment @deploymentSplat -WhatIf -WhatIfResultFormat FullResourcePayloads -Verbose 2>&1
        }

        Write-Host $whatIfResult
        Write-Log "What-If operation completed." -Level Success
    } else {
        Write-Log "Starting deployment..." -Level Info

        # Execute actual deployment
        if ($Quiet) {
            $deployment = New-AzSubscriptionDeployment @deploymentSplat
        } else {
            $deployment = New-AzSubscriptionDeployment @deploymentSplat -Verbose
        }

        if ($deployment.ProvisioningState -eq 'Succeeded') {
            Write-Log "Deployment completed successfully!" -Level Success
            Write-Host ""
            Write-Log "Deployment details:" -Level Info
            Write-Host "  Deployment name: $($deployment.DeploymentName)"
            Write-Host "  Budget name: $BudgetName"
            Write-Host "  Amount: $Amount ($TimeGrain)"
            Write-Host "  Status: $($deployment.ProvisioningState)"
            Write-Host "  Timestamp: $($deployment.Timestamp)"
            Write-Host ""
            Write-Log "Budget has been configured and will monitor costs for this subscription." -Level Info
            Write-Log "Notifications will be sent to: $($ContactEmails -join ', ')" -Level Info
        } else {
            Write-Log "Deployment failed with status: $($deployment.ProvisioningState)" -Level Error
            if ($deployment.Error) {
                Write-Log "Error details: $($deployment.Error.Message)" -Level Error
            }
            throw "Deployment failed"
        }
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
finally {
    Write-Log "Script execution completed." -Level Info
}

#endregion
