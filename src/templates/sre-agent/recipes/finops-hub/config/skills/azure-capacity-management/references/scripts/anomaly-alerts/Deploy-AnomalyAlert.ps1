#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy anomaly alert configuration to an Azure subscription.

.DESCRIPTION
    This script deploys the anomaly alert Bicep template to create a subscription-level
    scheduled action for cost anomaly monitoring. The script handles subscription
    validation, parameter collection, and deployment with proper error handling.

.PARAMETER SubscriptionId
    The target Azure subscription ID where the anomaly alert will be deployed.
    If not provided, the script will prompt for selection from available subscriptions.

.PARAMETER EmailRecipients
    Array of email addresses that'll receive anomaly alert notifications.
    These should be valid email addresses of stakeholders who need to be notified.

.PARAMETER NotificationEmail
    Primary notification email address for the anomaly alert system.
    This is typically an administrative or monitoring email address.

.PARAMETER DeploymentName
    Optional custom name for the deployment. If not provided, a timestamped name will be generated.

.PARAMETER Location
    Azure region for the deployment. Defaults to 'West US' if not specified.
    Note: This is only for deployment metadata, not resource location.

.PARAMETER Force
    Skip confirmation prompts and proceed with deployment automatically.

.PARAMETER Quiet
    Suppress verbose deployment progress output to avoid the 5-second polling wait.

.EXAMPLE
    ./Deploy-AnomalyAlert.ps1 -EmailRecipients @("admin@company.com", "finance@company.com") -NotificationEmail "alerts@company.com"
    
    Deploy anomaly alert with interactive subscription selection and specified email addresses.

.EXAMPLE
    ./Deploy-AnomalyAlert.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -WhatIf
    
    Show what would be deployed in the specified subscription without actually deploying.

.EXAMPLE
    ./Deploy-AnomalyAlert.ps1 -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -Force
    
    Deploy without confirmation prompts.

.NOTES
    - Requires Azure PowerShell module (Az)
    - User must be authenticated to Azure (Connect-AzAccount)
    - User must have appropriate permissions to create subscription-level resources
    - The deployment creates a cost management scheduled action for anomaly detection
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$EmailRecipients,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NotificationEmail,

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

function Confirm-Deployment {
    param(
        [object]$Subscription,
        [string[]]$EmailRecipients,
        [string]$NotificationEmail,
        [string]$DeploymentName
    )
    
    if ($Force) {
        return $true
    }
    
    Write-Host ""
    Write-Log "Deployment summary:" -Level Info
    Write-Host "  Subscription: $($Subscription.Name) ($($Subscription.Id))"
    Write-Host "  Deployment name: $DeploymentName"
    Write-Host "  Email recipients: $($EmailRecipients -join ', ')"
    Write-Host "  Notification email: $NotificationEmail"
    Write-Host ""
    
    $confirmation = Read-Host "Do you want to proceed with this deployment? (y/N)"
    return ($confirmation -eq 'y' -or $confirmation -eq 'Y')
}

#endregion

#region Main Script

try {
    Write-Log "Starting anomaly alert deployment script..." -Level Info
    
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
    
    # Generate deployment name if not provided
    if (-not $DeploymentName) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $DeploymentName = "anomaly-alert-$timestamp"
    }
    
    # Get the script directory and template path
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $templateFile = Join-Path $scriptDir "anomaly-alert.bicep"
    
    # Verify template file exists
    if (-not (Test-Path $templateFile)) {
        throw "Bicep template file not found: $templateFile"
    }
    
    Write-Log "Template file found: $templateFile" -Level Success
    
    # Validate email addresses
    $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    foreach ($email in $EmailRecipients) {
        if ($email -notmatch $emailRegex) {
            throw "Invalid email address format: $email"
        }
    }
    
    if ($NotificationEmail -notmatch $emailRegex) {
        throw "Invalid notification email address format: $NotificationEmail"
    }
    
    Write-Log "Email addresses validated." -Level Success
    
    # Prepare deployment parameters
    $deploymentParams = @{
        emailRecipients = $EmailRecipients
        notificationEmail = $NotificationEmail
    }
    
    # Show deployment summary and get confirmation
    if (-not (Confirm-Deployment -Subscription $targetSubscription -EmailRecipients $EmailRecipients -NotificationEmail $NotificationEmail -DeploymentName $DeploymentName)) {
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
        $deploymentSplat.Add('WhatIf', $true)
        Write-Log "Running deployment validation (What-If)..." -Level Info
    } else {
        Write-Log "Starting deployment..." -Level Info
    }
    
    # Execute deployment
    if ($PSCmdlet.ShouldProcess($targetSubscription.Name, "Deploy anomaly alert")) {
        if ($Quiet) {
            $deployment = New-AzSubscriptionDeployment @deploymentSplat
        } else {
            $deployment = New-AzSubscriptionDeployment @deploymentSplat -Verbose
        }
        
        if (-not $WhatIfPreference) {
            if ($deployment.ProvisioningState -eq 'Succeeded') {
                Write-Log "Deployment completed successfully!" -Level Success
                Write-Host ""
                Write-Log "Deployment details:" -Level Info
                Write-Host "  Deployment name: $($deployment.DeploymentName)"
                Write-Host "  Resource ID: $($deployment.Id)"
                Write-Host "  Status: $($deployment.ProvisioningState)"
                Write-Host "  Timestamp: $($deployment.Timestamp)"
                Write-Host ""
                Write-Log "Anomaly alert has been configured and will monitor cost anomalies for this subscription." -Level Info
                Write-Log "Notifications will be sent to: $($EmailRecipients -join ', ')" -Level Info
            } else {
                Write-Log "Deployment failed with status: $($deployment.ProvisioningState)" -Level Error
                if ($deployment.Error) {
                    Write-Log "Error details: $($deployment.Error.Message)" -Level Error
                }
                throw "Deployment failed"
            }
        } else {
            Write-Log "What-If operation completed. Review the output above." -Level Success
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
