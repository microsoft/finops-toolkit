# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates a new Cost Management export.

    .PARAMETER Name
    Required. Name of the export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER Dataset
    Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost". Default = "ActualCost".

    .PARAMETER Monthly
    Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.

    .PARAMETER OneTime
    Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.

    .PARAMETER StartDate
    Optional. Day to start running exports. If -OneTime is set, this is required (not defaulted) and is used as the first day to query data for. Default = DateTime.Now.

    .PARAMETER EndDate
    Optional. Last day to run the export. If -OneTime is set, this is required (not defaulted) and is used as the last day to query data for. Default = 5 years from -StartDate.

    .PARAMETER StorageAccountId
    Required. Resource ID of the storage account to export data to.

    .PARAMETER StorageContainer
    Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".

    .PARAMETER StoragePath
    Optional. Path to export data to within the storage container. Default = (scope ID).
    
    .PARAMETER Execute
    Optional. Indicates that the export should be run immediately after created.

    .PARAMETER Backfill
    Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

    .EXAMPLE

    New-FinopsCostExport -Name 'July2023OneTime' `
	-Scope "subscriptions/e690a198-d672-41ba-8e53-41c6441319fc" `
	-StorageAccountId "/subscriptions/e690a198-d672-41ba-8e53-41c6441319fc/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
	-OneTime `
	-DataSet ActualCost `
	-StartDate "2023-07-01" `
	-EndDate "2023-07-31" `
	-Verbose

    Creates a new one time export called 'July2023OneTime from 2023-07-01 to 2023-07-31 with Dataset = Actual and execute it once.

    .EXAMPLE

    New-FinopsCostExport -Name 'DailyMTD' `
	-Scope "subscriptions/e690a198-d672-41ba-8e53-41c6441319fc" `
	-StorageAccountId "/subscriptions/e690a198-d672-41ba-8e53-41c6441319fc/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
	-DataSet AmortizedCost `
	-EndDate "2024-12-31" `
	-Execute `
	-Verbose

    Creates a new scheduled export called Daily-MTD with StartDate = DateTime.Now and EndDate = 2024-12-31. Export is run immediately after creation.

	.EXAMPLE

    New-FinopsCostExport -Name 'Monthly-Report' `
	-Scope "subscriptions/e690a198-d672-41ba-8e53-41c6441319fc" `
	-StorageAccountId "/subscriptions/e690a198-d672-41ba-8e53-41c6441319fc/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
	-DataSet AmortizedCost `
	-StartDate $(get-date).adddays(5) `
	-EndDate "2024-08-15" `
	-Monthly `
	-Execute `
	-Verbose

    Creates a new monthly export called Monthly-Report with StartDate = 1 day from DateTime.Now and EndDate 2024-08-15. Export is run immediately after creation.

	.EXAMPLE

    New-FinopsCostExport -Name 'Daily-MTD' `
	-Scope "subscriptions/e690a198-d672-41ba-8e53-41c6441319fc" `
	-StorageAccountId "/subscriptions/e690a198-d672-41ba-8e53-41c6441319fc/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
	-DataSet Usage `
	-StorageContainer "costreports" `
	-Backfill 4 `
	-Execute `
	-Verbose

    Creates a new daily export called Daily-MTD with StartDate = DateTime.Now and EndDate 5 years from StartDate. Additiionally, export cost data for the previous 4 months and save all results in costreports container of the specified storage account.
    
	.LINK
    https://aka.ms/ftk/New-FinOpsCostExport
#>

function New-FinOpsCostExport
{
	[cmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$Scope,

		[Parameter()]
		[ValidateSet("ActualCost", "AmortizedCost", "Usage")]
		[string]
		$DataSet = "ActualCost",

		[Parameter(ParameterSetName = "Scheduled")]
		[switch]
		$Monthly,

		[Parameter(ParameterSetName = "OneTime")]
		[switch]
		$OneTime,

		[Parameter(ParameterSetName = "OneTime", Mandatory = $true)]
		[Parameter(ParameterSetName = "Scheduled")]
		[System.DateTime]
		$StartDate = $(Get-Date),

		[Parameter(ParameterSetName = "OneTime", Mandatory = $true)]
		[Parameter(ParameterSetName = "Scheduled")]
		[System.DateTime]
		$EndDate = $StartDate.addyears(5),

		[Parameter(Mandatory = $true)]
		[string]
		$StorageAccountId,

		[Parameter()]
		[string]
		$StorageContainer = "cost-management",

		[Parameter()]
		[string]
		$StoragePath,

		[Parameter()]
		[switch]
		$Execute,

		[Parameter(ParameterSetName = "Scheduled")]
		[int32]
		$Backfill = 0,

		[Parameter()]
		[string]
		$ApiVersion = '2023-08-01'
	)  

	$context = Get-AzContext
	if (-not $context)
	{
		throw $script:localizedData.ContextNotFound
	}

	$scope = $scope.Trim("/")

	if ([System.String]::IsNullOrEmpty($StoragePath))
	{
		$StoragePath = $Scope
	}
	
    $StorageContainer=$StorageContainer.tolower()
	$path = "$scope/providers/Microsoft.CostManagement/exports/$Name`?api-version=$ApiVersion"

	# Register the Microsoft.CostManagementExports resource provider.

	if ($(Get-AzResourceProvider -ProviderNamespace Microsoft.CostManagementExports).RegistrationState -ne 'Registered')
	{
		Write-Verbose "Microsoft.CostManagementExports provider is not registered. Registering provider."
		Register-AzResourceProvider -ProviderNamespace 'Microsoft.CostManagementExports'
	}
	else
	{
		Write-Verbose "Provider Microsoft.CostManagementExports is registered"
	}


	if ($Monthly) { $recurrence = "Monthly" } else { $recurrence = "Daily" }

	# Use "MonthToDate" unless -OneTime is enabled, then use "Custom"
	if ($OneTime) { $timeframe = "Custom"; $schedulestatus = "Inactive" } else { $timeframe = "MonthToDate"; $schedulestatus = "Active" }


	$StartDatestr = "$($StartDate.tostring("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'"))"
	$EndDatestr = $EndDate.tostring("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")

	$scheduledproperties = @"
{
  
  "identity": {
    "type": "SystemAssigned"
  },
  "location": "centralus",
  "properties": {
    "schedule": {
      "status": "$schedulestatus",
      "recurrence": "$recurrence",
      "recurrencePeriod": {
        from: "$StartDatestr",
        to: "$EndDatestr",
      }
    },
    "format": "Csv",
    "deliveryInfo": {
      "destination": {
        "resourceId": "$StorageAccountId",
        "container": "$StorageContainer",
        "rootFolderPath": "$StoragePath"
      }
    },
    "definition": {
      "type": "$DataSet",
      "timeframe": "$timeframe",
      "dataSet": {
        "granularity": "Daily"
      }
    }
  }
}
"@ 

	$onetimeproperties = @"
{
  
  "identity": {
    "type": "SystemAssigned"
  },
  "location": "centralus",
  "properties": {
    "format": "Csv",
    "deliveryInfo": {
      "destination": {
        "resourceId": "$StorageAccountId",
        "container": "$StorageContainer",
        "rootFolderPath": "$StoragePath"
      }
    },
    "definition": {
      "type": "$DataSet",
      "timeframe": "$timeframe",
      "dataSet": {
        "granularity": "Daily"
      },
      "timePeriod": {
        "from": "$StartDatestr",
        "to": "$EndDatestr"
    }
    }
  }
}
"@ 

	if ($onetime) { $properties = $onetimeproperties ; $execute = $true } else { $properties = $scheduledproperties }

	$propertiesobj = $properties | ConvertFrom-Json
	$createresponse = $null
    
	#Check if export with same name exists in scope. If it exists, update will be performed using etag.

	write-verbose "Checking if Export $Name exists with path $path"
	$getresult = Invoke-Rest -Path $path -Method GET -ErrorAction SilentlyContinue
	
	if ($getresult.StatusCode -eq 200)
	{
		Write-Output "Export with name $name already exists in scope $scope. Updating export."
        $etag = $($getresult.Content | ConvertFrom-Json).etag #needed for update

		$propobj=$propertiesobj 
		write-verbose "Adding etag to the request for modify request"
		$propobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | convertto-json -Depth 100
		$properties = $propobj | convertto-json -Depth 100
		$createresponse = Invoke-Rest -Path "$path" -Method PUT -Payload $properties

		if ($Execute -eq $true -and !($($createresponse.Content | ConvertFrom-Json).error))
			{
				$runpath = "$scope/providers/Microsoft.CostManagement/exports/$Name/run?api-version=$ApiVersion"
				Write-Verbose "Executing export $runpath"
				$executeresponse=Invoke-Rest -Path $runpath -Method POST
				if($executeresponse.StatusCode -eq 200) 
				{
					write-verbose "Export executed successfully"
				}
			}
		
		
		
	}
	else
	{
		# Create the export using the JSON properties below.
		Write-Output "Creating new export with name $Name"
		Write-Verbose "Creating a new export from $startdatestr to $enddatestr : $path"
		$createresponse = Invoke-Rest -Path "$path" -Method PUT -Payload $properties

		if ($Execute -eq $true -and !($($createresponse.Content | ConvertFrom-Json).error))
		{
			$runpath = "$scope/providers/Microsoft.CostManagement/exports/$Name/run?api-version=$ApiVersion"
			Write-Verbose "Executing export $runpath"
			$runresponse=Invoke-Rest -Path $runpath -Method POST
			if($runresponse.StatusCode -eq 200) 
				{
					write-verbose "Export executed successfully"
				}
		}
	}
	
	#once set, change the export to be a one-time export for the previous month. Keep all other settings as-is. This should auto-trigger a run and repeat for each month

	if ($Backfill -gt 0 -and !($($createresponse.Content | ConvertFrom-Json).error))
	{
		$propertiesobj = $onetimeproperties | ConvertFrom-Json
		Write-Output "Running backfill for $backfill months"
		$counter = 1
		$propertiesobj.properties.definition.timeframe = "Custom"      
		do
		{
			
			$getresult=$null
			#run get to fetch etag since this is an update operation.
			$getresult = Invoke-Rest -Path $path -Method GET
			$etag = $($getresult.Content | ConvertFrom-Json).etag #needed for update

			#insert etag in the properies object and convert it to json
			$propertiesobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | convertto-json -Depth 100

			Write-Verbose "Month $counter of $backfill"
			$startofcurrentmonth = [datetime]$(Get-Date -Day 1).tostring("yyyy-MM-dd")

			$startofpreviousmonth = $startofcurrentmonth.AddMonths($counter * -1)
			$endofpreviousmonth = $startofpreviousmonth.AddMonths(1).AddMilliseconds($counter * -1).tostring("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
			$startofpreviousmonth = $startofpreviousmonth.tostring("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
			$propertiesobj.properties.definition.timePeriod.to = $endofpreviousmonth
			$propertiesobj.properties.definition.timePeriod.from = $startofpreviousmonth

			$backfillsettings = $null
			$backfillsettings = $propertiesobj | ConvertTo-Json -Depth 100

			Write-Verbose -Message "Running backfill export from $startofpreviousmonth to $endofpreviousmonth"
			Write-Verbose -Message "$($backfillsettings)" 
			$httpResponse = Invoke-Rest -Path $path -Method PUT -Payload $backfillsettings

			if (!($($httpResponse.Content | ConvertFrom-Json).error))
			{
				Write-Verbose "Updated export for onetime export of previous month. Executing export"
				$httpResponse = $null
				$runpath = "$scope/providers/Microsoft.CostManagement/exports/$Name/run?api-version=$ApiVersion"
				Write-Verbose "Executing export $runpath"
				$runresponse=Invoke-Rest -Path $runpath -Method POST
				if($runresponse.StatusCode -eq 200) 
				{
					Write-Output "Export executed successfully for month $startofpreviousmonth to $endofpreviousmonth"
				}
			
			}

			$counter += 1
			Start-Sleep 2
		}while ($counter -le $Backfill)

		Write-Output "Backfill complete. Updating export settings back to original scheduled settings"

		$getresult = Invoke-Rest -Path $path -Method GET
		$etag = $($getresult.Content | ConvertFrom-Json).etag #needed for update

		
		$propertiesobj = $properties | ConvertFrom-Json
		$propertiesobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | convertto-json -Depth 100
		$properties = $propertiesobj | convertto-json -Depth 100
		$httpResponse = Invoke-Rest -Path $path -Method PUT -Payload $properties
		

	}
}


