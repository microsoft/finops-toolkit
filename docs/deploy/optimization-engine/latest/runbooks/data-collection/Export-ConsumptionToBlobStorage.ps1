param(
    [Parameter(Mandatory = $false)]
    [string] $TargetSubscription,

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName,

    [Parameter(Mandatory = $false)] 
    [string] $targetStartDate, # YYYY-MM-DD format

    [Parameter(Mandatory = $false)] 
    [string] $targetEndDate # YYYY-MM-DD format
)

$ErrorActionPreference = "Stop"
$global:hadErrors = $false
$global:scopesWithErrors = @()

function Authenticate-AzureWithOption {
    param (
        [string] $authOption = "ManagedIdentity",
        [string] $cloudEnv = "AzureCloud",
        [string] $clientID 
    )

    switch ($authOption) {
        "UserAssignedManagedIdentity" { 
            Connect-AzAccount -Identity -EnvironmentName $cloudEnv -AccountId $clientID
            break
        }
        Default { #ManagedIdentity
            Connect-AzAccount -Identity -EnvironmentName $cloudEnv 
            break
        }
    }
}

function Generate-CostDetails {
    param (        
        [string] $ScopeId,
        [string] $ScopeName 
    )

    $MaxTries = 20 # The typical Retry-After is set to 20 seconds. We'll give ~6 minutes overall to download the cost details report
    $hadErrors = $false

    $CostDetailsApiPath = "$ScopeId/providers/Microsoft.CostManagement/generateCostDetailsReport?api-version=2022-05-01"
    $body = "{ `"metric`": `"$consumptionMetric`", `"timePeriod`": { `"start`": `"$targetStartDate`", `"end`": `"$targetEndDate`" } }"
    $result = Invoke-AzRestMethod -Path $CostDetailsApiPath -Method POST -Payload $body
    $requestResultPath = $result.Headers.Location.PathAndQuery
    if ($result.StatusCode -in (200,202))
    {
        $tries = 0
        $requestSuccess = $false

        Write-Output "Obtained cost detail results endpoint: $requestResultPath..."

        Write-Output "Was told to wait $($result.Headers.RetryAfter.Delta.TotalSeconds) seconds."

        $sleepSeconds = 60
        if ($result.Headers.RetryAfter.Delta.TotalSeconds -gt 0)
        {
            $sleepSeconds = $result.Headers.RetryAfter.Delta.TotalSeconds
        }

        do
        {
            $tries++
            Write-Output "Checking whether export is ready (try $tries)..."
            
            Start-Sleep -Seconds $sleepSeconds
            $downloadResult = Invoke-AzRestMethod -Method GET -Path $requestResultPath

            if ($downloadResult.StatusCode -eq 200)
            {

                Write-Output "Export is ready. Proceeding with CSV download..."

                $downloadBlobJson = $downloadResult.Content | ConvertFrom-Json

                $blobCounter = 0
                foreach ($blob in $downloadBlobJson.manifest.blobs)
                {
                    $blobCounter++

                    Write-Output "Downloading blob $blobCounter..."

                    $csvExportPath = "$env:TEMP\$targetStartDate-$ScopeName-$consumptionMetric-$blobCounter.csv"
                    $finalCsvExportPath = "$env:TEMP\$targetStartDate-$ScopeName-$consumptionMetric-$blobCounter-final.csv"

                    Invoke-WebRequest -Uri $blob.blobLink -OutFile $csvExportPath

                    Write-Output "Blob downloaded to $csvExportPath successfully."

                    $r = [IO.File]::OpenText($csvExportPath)
                    $w = [System.IO.StreamWriter]::new($finalCsvExportPath)

                    # header normalization between MCA and EA
                    $headerConversion = @{
                        additionalInfo = "AdditionalInfo";
                        billingAccountId = "BillingAccountId";
                        billingAccountName = "BillingAccountName";
                        billingCurrency = "BillingCurrencyCode";
                        billingPeriodEndDate = "BillingPeriodEndDate";
                        billingPeriodStartDate = "BillingPeriodStartDate";
                        billingProfileId = "BillingProfileId";
                        billingProfileName = "BillingProfileName";
                        chargeType = "ChargeType";
                        consumedService = "ConsumedService";
                        costAllocationRuleName = "CostAllocationRuleName";
                        costCenter = "CostCenter";
                        costInBillingCurrency = "CostInBillingCurrency";
                        date = "Date";
                        effectivePrice = "EffectivePrice";
                        frequency = "Frequency";
                        invoiceSectionId = "InvoiceSectionId";
                        invoiceSectionName = "InvoiceSectionName";
                        isAzureCreditEligible = "IsAzureCreditEligible";
                        meterCategory = "MeterCategory";
                        meterId = "MeterId";
                        meterName = "MeterName";
                        meterRegion = "MeterRegion";
                        meterSubCategory = "MeterSubCategory";
                        offerId = "OfferId";
                        pricingModel = "PricingModel";
                        productOrderId = "ProductOrderId";
                        productOrderName = "ProductOrderName";
                        publisherName = "PublisherName";
                        publisherType = "PublisherType";
                        quantity = "Quantity";
                        reservationId = "ReservationId";
                        reservationName = "ReservationName";
                        resourceGroupName = "ResourceGroup";
                        resourceLocation = "ResourceLocation";
                        serviceFamily = "ServiceFamily";
                        serviceInfo1 = "ServiceInfo1";
                        serviceInfo2 = "ServiceInfo2";
                        subscriptionName = "SubscriptionName";
                        tags = "Tags";
                        term = "Term";
                        unitOfMeasure = "UnitOfMeasure";
                        unitPrice = "UnitPrice"
                    }

                    $lineCounter = 0
                    while ($r.Peek() -ge 0) {
                        $line = $r.ReadLine()
                        $lineCounter++
                        if ($lineCounter -eq 1)
                        {
                            $headers = $line.Split(",")

                            for ($i = 0; $i -lt $headers.Length; $i++)
                            {
                                $header = $headers[$i]
                                if ($headerConversion.ContainsKey($header))
                                {
                                    $headers[$i] = $headerConversion[$header]
                                }
                            }

                            $line = $headers -join ","

                            $w.WriteLine($line)
                        }
                        else
                        {
                            $w.WriteLine($line)
                        }
                    }
                    $r.Dispose()
                    $w.Close()        

                    $csvBlobName = [System.IO.Path]::GetFileName($finalCsvExportPath)
                    $csvProperties = @{"ContentType" = "text/csv"};
                    Set-AzStorageBlobContent -File $finalCsvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force
                    
                    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                    Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."
                
                    Remove-Item -Path $csvExportPath -Force
                
                    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                    Write-Output "[$now] Removed $csvExportPath from local disk..."                    

                    Remove-Item -Path $finalCsvExportPath -Force
        
                    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                    Write-Output "[$now] Removed $finalCsvExportPath from local disk..."                            
                }

                $requestSuccess = $true
            }
            elseif ($downloadResult.StatusCode -eq 202)
            {
                Write-Output "Was told to wait a bit more... $($downloadResult.Headers.RetryAfter.Delta.TotalSeconds) seconds."

                $sleepSeconds = 60
                if ($downloadResult.Headers.RetryAfter.Delta.TotalSeconds -gt 0)
                {
                    $sleepSeconds = $downloadResult.Headers.RetryAfter.Delta.TotalSeconds
                }
            }
            elseif ($downloadResult.StatusCode -eq 401)
            {
                Write-Output "Had an authentication issue. Will login again and sleep just a couple of seconds."

                if ($authenticationOption -eq "UserAssignedManagedIdentity")
                {
                    Authenticate-AzureWithOption -authOption $authenticationOption -cloudEnv $cloudEnvironment -clientID $uamiClientID
                }
                else
                {    
                    Authenticate-AzureWithOption -authOption $authenticationOption -cloudEnv $cloudEnvironment
                }
                
                $sleepSeconds = 2
            }
            else
            {
                $global:hadErrors = $true
                $global:scopesWithErrors += $ScopeName
                Write-Warning "Got an unexpected response code: $($downloadResult.StatusCode)"
            }
        } 
        while (-not($requestSuccess) -and $tries -lt $MaxTries)

        if (-not($requestSuccess))
        {
            $global:hadErrors = $true
            $global:scopesWithErrors += $ScopeName
            if ($tries -eq $MaxTries)
            {
                Write-Warning "Reached maximum number of tries. Aborting..."
            }
            else
            {
                Write-Warning "Error returned by the Download Cost Details API. Status Code: $($downloadResult.StatusCode). Message: $($downloadResult.Content)"    
            }
        }
        else
        {
            Write-Output "Export download processing complete."
        }
    }
    else
    {
        if ($result.StatusCode -ne 204)
        {
            $global:hadErrors = $true
            $global:scopesWithErrors += $ScopeName
            Write-Warning "Error returned by the Generate Cost Details API. Status Code: $($result.StatusCode). Message: $($result.Content)"
        }
        else
        {
            Write-Output "Request returned 204 No Content"
        }
    }
}

$cloudEnvironment = Get-AutomationVariable -Name "AzureOptimization_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}
$authenticationOption = Get-AutomationVariable -Name  "AzureOptimization_AuthenticationOption" -ErrorAction SilentlyContinue # ManagedIdentity|UserAssignedManagedIdentity
if ([string]::IsNullOrEmpty($authenticationOption))
{
    $authenticationOption = "ManagedIdentity"
}
if ($authenticationOption -eq "UserAssignedManagedIdentity")
{
    $uamiClientID = Get-AutomationVariable -Name "AzureOptimization_UAMIClientID"
}

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkEnv = Get-AutomationVariable -Name "AzureOptimization_StorageSinkEnvironment" -ErrorAction SilentlyContinue
if (-not($storageAccountSinkEnv))
{
    $storageAccountSinkEnv = $cloudEnvironment    
}
$storageAccountSinkKeyCred = Get-AutomationPSCredential -Name "AzureOptimization_StorageSinkKey" -ErrorAction SilentlyContinue
$storageAccountSinkKey = $null
if ($storageAccountSinkKeyCred)
{
    $storageAccountSink = $storageAccountSinkKeyCred.UserName
    $storageAccountSinkKey = $storageAccountSinkKeyCred.GetNetworkCredential().Password
}

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ConsumptionContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "consumptionexports"
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

$consumptionOffsetDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_ConsumptionOffsetDays")

$consumptionMetric = Get-AutomationVariable -Name  "AzureOptimization_ConsumptionMetric" -ErrorAction SilentlyContinue # AmortizedCost|ActualCost
if ([string]::IsNullOrEmpty($consumptionMetric))
{
    $consumptionMetric = "AmortizedCost"
}

$consumptionAPIOption = Get-AutomationVariable -Name  "AzureOptimization_ConsumptionAPIOption" -ErrorAction SilentlyContinue # CostDetails|UsageDetails
if ([string]::IsNullOrEmpty($consumptionAPIOption))
{
    $consumptionAPIOption = "CostDetails"
}

$consumptionScope = Get-AutomationVariable -Name  "AzureOptimization_ConsumptionScope" -ErrorAction SilentlyContinue # Subscription|BillingAccount
if ([string]::IsNullOrEmpty($consumptionScope))
{
    "Consumption Scope not specified, defaulting to Subscription"
    $consumptionScope = "Subscription"
}
else
{
    "Consumption Scope is $consumptionScope"
    if ($consumptionScope -eq "BillingAccount")
    {
        $BillingAccountID = Get-AutomationVariable -Name  "AzureOptimization_BillingAccountID"        
    }
    else
    {
        if ($consumptionScope -eq "BillingProfile")
        {
            $BillingAccountID = Get-AutomationVariable -Name  "AzureOptimization_BillingAccountID"        
            $BillingProfileID = Get-AutomationVariable -Name  "AzureOptimization_BillingProfileID"
        }
        else
        {
            if ($consumptionScope -ne "Subscription")
            {
                throw "Invalid value for AzureOptimization_ConsumptionScope. Valid values are 'Subscription' or 'BillingAccount'."
            }
        }
    }
}

if ($cloudEnvironment -eq "AzureChinaCloud")
{
    $chinaEAEnrollment = Get-AutomationVariable -Name "AzureOptimization_AzureChinaEAEnrollment" -ErrorAction SilentlyContinue    
    $chinaEAKey = Get-AutomationVariable -Name  "AzureOptimization_AzureChinaEAKey" -ErrorAction SilentlyContinue
}

"Logging in to Azure with $authenticationOption..."

if ($authenticationOption -eq "UserAssignedManagedIdentity")
{
    Authenticate-AzureWithOption -authOption $authenticationOption -cloudEnv $cloudEnvironment -clientID $uamiClientID
}
else
{    
    Authenticate-AzureWithOption -authOption $authenticationOption -cloudEnv $cloudEnvironment
}

if (-not($storageAccountSinkKey))
{
    Write-Output "Getting Storage Account context with login"
    
    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment
}
else
{
    Write-Output "Getting Storage Account context with key"
    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -StorageAccountKey $storageAccountSinkKey -Environment $storageAccountSinkEnv
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential 
    $cloudEnvironment = $externalCloudEnvironment   
}

# compute start+end dates

if ([string]::IsNullOrEmpty($targetStartDate) -or [string]::IsNullOrEmpty($targetEndDate))
{
    $targetStartDate = (Get-Date).Date.AddDays($consumptionOffsetDays * -1).ToString("yyyy-MM-dd")
    $targetEndDate = $targetStartDate    
}

if ($consumptionScope -eq "Subscription")
{
    if (-not([string]::IsNullOrEmpty($TargetSubscription)))
    {
        $subscriptions = Get-AzSubscription -SubscriptionId $TargetSubscription
    }
    else
    {
        $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
    }    
    "Exporting consumption data from $targetStartDate to $targetEndDate for $($subscriptions.Count) subscriptions..."
}
else
{
    "Exporting consumption data from $targetStartDate to $targetEndDate for $consumptionScope..."
}


# for each subscription, get billing data

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

if ($cloudEnvironment -eq "AzureChinaCloud" -and -not([string]::IsNullOrEmpty($chinaEAEnrollment)) -and -not([string]::IsNullOrEmpty($chinaEAKey)))
{
    $targetMonth = $targetStartDate.Substring(0,7)
    $consumption = $null
    $billingEntries = @()
    
    $BillingApiUri = "https://ea.azure.cn/rest/$chinaEAEnrollment/usage-report?month=$targetMonth&type=detail&fmt=Csv"
    $PricesheetApiUri = "https://ea.azure.cn/rest/$chinaEAEnrollment/usage-report?month=$targetMonth&type=pricesheet&fmt=Csv"
        
    $Headers = @{}
    $Headers.Add("Authorization","Bearer $chinaEAKey")
    
    Write-Output "Getting pricesheet for month $targetMonth (EA enrollment $chinaEAEnrollment)..."
    
    Invoke-RestMethod -Method Get -Uri $PricesheetApiUri -Headers $Headers -OutFile "pricesheet-$targetMonth.csv"
    
    Write-Output "Pricesheet data exported to disk as CSV."
    
    $csvFile = Get-Content -Path "pricesheet-$targetMonth.csv"
    
    Write-Output "Pricesheet data imported from disk as string."
    
    Remove-Item -Path "pricesheet-$targetMonth.csv" -Force
    
    Write-Output "Removed pricesheet-$targetMonth.csv from local disk..."    
    
    $csvFile2 = $csvFile[2..($csvFile.Count-1)]
    $headerLine = $csvFile2[0]
    $columnHeaders = $headerLine.Split(",")
    for ($i = 0; $i -lt $columnHeaders.Count; $i++)
    {
        if($columnHeaders[$i] -match '.+\((?<ColumnName>.+)\)')
        {
            $columnHeaders[$i] = $Matches.ColumnName
        }
    }
    $csvFile2[0] = $columnHeaders -join ","
    
    Write-Output "Removed first 2 lines and replaced header."
    
    $pricesheet = $csvFile2 | ConvertFrom-Csv
    
    Write-Output "Starting Azure China billing export process from $targetStartDate to $targetEndDate (month $targetMonth) for EA enrollment $chinaEAEnrollment..."
    
    $tries = 0
    $requestSuccess = $false
    do 
    {
        try {
            $tries++
            Invoke-RestMethod -Method Get -Uri $BillingApiUri -Headers $Headers -OutFile "usagedetails-$targetStartDate.csv"
    
            Write-Output "Consumption data exported to disk as CSV."
    
            $csvFile = Get-Content -Path "usagedetails-$targetStartDate.csv"
    
            Write-Output "Consumption data imported from disk as string."
    
            Remove-Item -Path "usagedetails-$targetStartDate.csv" -Force
    
            Write-Output "Removed usagedetails-$targetStartDate.csv from local disk..."    
            
            $csvFile2 = $csvFile[2..($csvFile.Count-1)]
            $headerLine = $csvFile2[0]
            $columnHeaders = $headerLine.Split(",")
            for ($i = 0; $i -lt $columnHeaders.Count; $i++)
            {
                if($columnHeaders[$i] -match '.+\((?<ColumnName>.+)\)')
                {
                    $columnHeaders[$i] = $Matches.ColumnName
                }
            }
            $csvFile2[0] = $columnHeaders -join ","
    
            Write-Output "Removed first 2 lines and replaced header."
    
            $consumption = $csvFile2 | ConvertFrom-Csv  
            $requestSuccess = $true
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Warning "Error getting consumption data: $ErrorMessage. $tries of 3 tries. Waiting 60 seconds..."
            Start-Sleep -s 60   
        }
    
    } while ( -not($requestSuccess) -and $tries -lt 3 )
    
    if (-not($requestSuccess))
    {
        throw "Failed consumption export"
    }
    
    Write-Output "Consumption data in memory as CSV. Processing lines..."
    
    foreach ($consumptionLine in $consumption)
    {
        $usageDate = [Datetime]::ParseExact($consumptionLine.Date, 'MM/dd/yyyy', $null).ToString("yyyy-MM-dd")
    
        if ($usageDate -ge $targetStartDate -and $usageDate -le $targetEndDate -and ($subscriptions.Count -gt 1 -or $subscriptions.Id -eq $consumptionLine.SubscriptionGuid))
        {
            $instanceId = $null
            $instanceName = $null
            if ($null -ne $consumptionLine.'Instance ID')
            {
                $instanceId = $consumptionLine.'Instance ID'.ToLower()
                $idParts = $consumptionLine.'Instance ID'.Split("/")
                $instanceName = $idParts[$idParts.Count-1].ToLower()
            }
        
            $rgName = $null
            if ($null -ne $consumptionLine.'Resource Group')
            {
                $rgName = $consumptionLine.'Resource Group'.ToLower()
            }
        
            $convertedCost = 0.0    
            if ([double]$consumptionLine.ExtendedCost -ne 0)
            {
                $convertedCost = [double]$consumptionLine.ExtendedCost
            }
            $convertedPrice = 0.0    
            if ([double]$consumptionLine.ResourceRate -ne 0)
            {
                $convertedPrice = [double]$consumptionLine.ResourceRate
            }
    
            $unitPrice = 0.0
            $partNumber = "N/A"
            foreach ($priceItem in $pricesheet)
            {
                if ($priceItem.Service -eq $consumptionLine.Product)
                {
                    $partNumber = $priceItem.'Part Number'
                    if ($consumptionLine.'Meter Category' -eq "Virtual Machines")
                    {
                        $tempUnitPrice = [double] $priceItem.'Unit Price'
                        $uom = $priceItem.'Unit of Measure'
                        $currentUnitHours = [int] (Select-String -InputObject $uom -Pattern "^\d+").Matches[0].Value
                        if ($currentUnitHours -gt 0)
                        {
                            $unitPrice = [double] ($tempUnitPrice / $currentUnitHours)
                        }    
                    }
                    else
                    {
                        $unitPrice = $convertedPrice    
                    }
                    break
                }
            }
        
            $billingEntry = New-Object PSObject -Property @{
                Timestamp = $timestamp
                SubscriptionId = $consumptionLine.SubscriptionGuid
                ResourceGroup = $rgName
                ResourceName = $instanceName
                ResourceId = $instanceId
                Date = $consumptionLine.Date
                Tags = $consumptionLine.Tags
                AdditionalInfo = $consumptionLine.AdditionalInfo
                BillingCurrencyCode = "CNY"
                ChargeType = "Usage"
                ConsumedService = $consumptionLine.'Consumed Service'
                CostInBillingCurrency = $convertedCost
                EffectivePrice = $convertedPrice
                Frequency = "UsageBased"
                MeterCategory = $consumptionLine.'Meter Category'
                MeterId = $consumptionLine.'Meter ID'
                MeterName = $consumptionLine.'Meter Name'
                MeterSubCategory = $consumptionLine.'Meter Sub-Category'
                PartNumber = $partNumber
                ProductName = $consumptionLine.Product
                Quantity = $consumptionLine.'Consumed Quantity'
                UnitOfMeasure = $consumptionLine.'Unit of Measure'
                UnitPrice = $unitPrice
                ResourceLocation = $consumptionLine.'Resource Location'
                AccountOwnerId = $consumptionLine.AccountOwnerId
            }
            
            $billingEntries += $billingEntry    
        }
    }    
    
    if ($targetStartDate -ne $targetEndDate)
    {
        $targetStartDate = "$targetStartDate-$targetEndDate"
    }
        
    $csvExportPath = "$targetStartDate-eachina.csv"
    
    $billingEntries | Export-Csv -Path $csvExportPath -NoTypeInformation
    
    Write-Output "Exported $($billingEntries.Count) entries as CSV to $csvExportPath"
    
    $csvBlobName = $csvExportPath
    $csvProperties = @{"ContentType" = "text/csv"};
    Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force
    
    Write-Output "Uploaded to blob storage!"
    
    Remove-Item -Path $csvExportPath -Force
    
    Write-Output "Removed $csvExportPath from local disk..."    
}
else
{
    if ($consumptionScope -eq "Subscription")
    {
        $CostDetailsSupportedQuotaIDs = @('EnterpriseAgreement_2014-09-01','Internal_2014-09-01','CSP_2015-05-01')
        $ConsumptionSupportedQuotaIDs = @('PayAsYouGo_2014-09-01','MSDN_2014-09-01')
        
        foreach ($subscription in $subscriptions)
        {
            $subscriptionQuotaID = $subscription.SubscriptionPolicies.QuotaId
        
            if ($subscriptionQuotaID -in $ConsumptionSupportedQuotaIDs -or $consumptionAPIOption -eq "UsageDetails")
            {
                $consumption = $null
                $billingEntries = @()
            
                $ConsumptionApiPath = "/subscriptions/$($subscription.Id)/providers/Microsoft.Consumption/usageDetails?api-version=2021-10-01&metric=$($consumptionMetric.ToLower())&%24expand=properties%2FmeterDetails%2Cproperties%2FadditionalInfo&%24filter=properties%2FusageStart%20ge%20%27$targetStartDate%27%20and%20properties%2FusageEnd%20le%20%27$targetEndDate%27"
            
                "Starting consumption export process from $targetStartDate to $targetEndDate for subscription $($subscription.Name)..."
            
                do
                {
                    if (-not([string]::IsNullOrEmpty($consumption.nextLink)))
                    {
                        $ConsumptionApiPath = $consumption.nextLink.Substring($consumption.nextLink.IndexOf("/subscriptions/"))
                    }
                    $tries = 0
                    $requestSuccess = $false
                    do 
                    {        
                        try {
                            $tries++
                            $consumption = (Invoke-AzRestMethod -Path $ConsumptionApiPath -Method GET).Content | ConvertFrom-Json                    
                            $requestSuccess = $true
                        }
                        catch {
                            $ErrorMessage = $_.Exception.Message
                            Write-Warning "Error getting consumption data: $ErrorMessage. $tries of 3 tries. Waiting 60 seconds..."
                            Start-Sleep -s 60   
                        }
                    } while ( -not($requestSuccess) -and $tries -lt 3 )
            
                    foreach ($consumptionLine in $consumption.value)
                    {
                        if ((Get-Date $consumptionLine.properties.date).ToString("yyyy-MM-dd") -ge $targetStartDate -and (Get-Date $consumptionLine.properties.date).ToString("yyyy-MM-dd") -le $targetEndDate)
                        {
                            if ($consumptionLine.tags)
                            {
                                $tags = $consumptionLine.tags | ConvertTo-Json -Compress
                            }
                            else
                            {
                                $tags = $null
                            }

                            if ([string]::IsNullOrEmpty($consumptionLine.properties.billingProfileId))
                            {
                                # legacy consumption schema
            
                                $billingEntry = New-Object PSObject -Property @{
                                    Timestamp = $timestamp
                                    AccountName = $consumptionLine.properties.accountName
                                    AccountOwnerId = $consumptionLine.properties.accountOwnerId
                                    AdditionalInfo = $consumptionLine.properties.additionalInfo
                                    benefitId = $consumptionLine.properties.benefitId
                                    benefitName = $consumptionLine.properties.benefitName
                                    BillingAccountId = $consumptionLine.properties.billingAccountId
                                    BillingAccountName = $consumptionLine.properties.billingAccountName
                                    BillingCurrencyCode = $consumptionLine.properties.billingCurrency
                                    BillingPeriodEndDate= $consumptionLine.properties.billingPeriodEndDate
                                    BillingPeriodStartDate= $consumptionLine.properties.billingPeriodStartDate
                                    BillingProfileId = $consumptionLine.properties.billingProfileId
                                    BillingProfileName= $consumptionLine.properties.billingProfileName
                                    ChargeType = $consumptionLine.properties.chargeType
                                    ConsumedService = $consumptionLine.properties.consumedService
                                    CostAllocationRuleName = $consumptionLine.properties.costAllocationRuleName
                                    CostCenter = $consumptionLine.properties.costCenter
                                    CostInBillingCurrency = $consumptionLine.properties.cost
                                    Date = (Get-Date $consumptionLine.properties.date).ToString("MM/dd/yyyy")
                                    EffectivePrice = $consumptionLine.properties.effectivePrice
                                    Frequency = $consumptionLine.properties.frequency
                                    InvoiceSectionName = $consumptionLine.properties.invoiceSection
                                    IsAzureCreditEligible = $consumptionLine.properties.isAzureCreditEligible
                                    MeterCategory = $consumptionLine.properties.meterDetails.meterCategory
                                    MeterId = $consumptionLine.properties.meterId
                                    MeterName = $consumptionLine.properties.meterDetails.meterName
                                    MeterRegion = $consumptionLine.properties.meterDetails.meterRegion
                                    MeterSubCategory = $consumptionLine.properties.meterDetails.meterSubCategory
                                    OfferId = $consumptionLine.properties.offerId
                                    PartNumber = $consumptionLine.properties.partNumber
                                    PayGPrice = $consumptionLine.properties.PayGPrice
                                    PlanName = $consumptionLine.properties.planName
                                    PricingModel = $consumptionLine.properties.pricingModel
                                    ProductName = $consumptionLine.properties.product
                                    PublisherName = $consumptionLine.properties.publisherName
                                    PublisherType = $consumptionLine.properties.publisherType
                                    Quantity = $consumptionLine.properties.quantity
                                    ReservationId = $consumptionLine.properties.reservationId
                                    ReservationName = $consumptionLine.properties.reservationName
                                    ResourceGroup = $consumptionLine.properties.resourceGroup
                                    ResourceId = $consumptionLine.properties.resourceId
                                    ResourceLocation = $consumptionLine.properties.resourceLocation
                                    ResourceName = $consumptionLine.properties.resourceName
                                    ServiceFamily = $consumptionLine.properties.meterDetails.serviceFamily
                                    SubscriptionId = $consumptionLine.properties.subscriptionId
                                    SubscriptionName = $consumptionLine.properties.subscriptionName
                                    Tags = $tags
                                    Term = $consumptionLine.properties.term
                                    UnitOfMeasure = $consumptionLine.properties.meterDetails.unitOfMeasure
                                    UnitPrice = $consumptionLine.properties.unitPrice
                                }            
                            }
                            else
                            {
                                # MCA consumption schema
                                $billingEntry = New-Object PSObject -Property @{
                                    Timestamp = $timestamp
                                    AdditionalInfo = $consumptionLine.properties.additionalInfo
                                    benefitId = $consumptionLine.properties.benefitId
                                    benefitName = $consumptionLine.properties.benefitName
                                    BillingAccountId = $consumptionLine.properties.billingAccountId
                                    BillingAccountName = $consumptionLine.properties.billingAccountName
                                    BillingCurrencyCode = $consumptionLine.properties.billingCurrencyCode
                                    BillingPeriodEndDate= $consumptionLine.properties.billingPeriodEndDate
                                    BillingPeriodStartDate= $consumptionLine.properties.billingPeriodStartDate
                                    BillingProfileId = $consumptionLine.properties.billingProfileId
                                    BillingProfileName= $consumptionLine.properties.billingProfileName
                                    ChargeType = $consumptionLine.properties.chargeType
                                    ConsumedService = $consumptionLine.properties.consumedService
                                    CostAllocationRuleName = $consumptionLine.properties.costAllocationRuleName
                                    CostCenter = $consumptionLine.properties.costCenter
                                    CostInBillingCurrency = $consumptionLine.properties.costInBillingCurrency
                                    costInPricingCurrency = $consumptionLine.properties.costInPricingCurrency
                                    costInUSD = $consumptionLine.properties.costInUSD
                                    customerName = $consumptionLine.properties.customerName
                                    Date = (Get-Date $consumptionLine.properties.date).ToString("MM/dd/yyyy")
                                    EffectivePrice = $consumptionLine.properties.effectivePrice
                                    exchangeRate = $consumptionLine.properties.exchangeRate
                                    exchangeRateDate = $consumptionLine.properties.exchangeRateDate
                                    exchangeRatePricingToBilling = $consumptionLine.properties.exchangeRatePricingToBilling
                                    Frequency = $consumptionLine.properties.frequency
                                    invoiceSectionId = $consumptionLine.properties.invoiceSectionId
                                    InvoiceSectionName = $consumptionLine.properties.invoiceSectionName
                                    IsAzureCreditEligible = $consumptionLine.properties.isAzureCreditEligible
                                    MeterCategory = $consumptionLine.properties.meterCategory
                                    MeterId = $consumptionLine.properties.meterId
                                    MeterName = $consumptionLine.properties.meterName
                                    MeterRegion = $consumptionLine.properties.meterRegion
                                    MeterSubCategory = $consumptionLine.properties.meterSubCategory
                                    PartNumber = $consumptionLine.properties.partNumber
                                    paygCostInBillingCurrency = $consumptionLine.properties.paygCostInBillingCurrency
                                    paygCostInUSD = $consumptionLine.properties.paygCostInUSD
                                    PayGPrice = $consumptionLine.properties.payGPrice
                                    PlanName = $consumptionLine.properties.planName
                                    pricingCurrencyCode = $consumptionLine.properties.pricingCurrencyCode
                                    PricingModel = $consumptionLine.properties.pricingModel
                                    ProductName = $consumptionLine.properties.product
                                    productIdentifier = $consumptionLine.properties.productIdentifier
                                    PublisherName = $consumptionLine.properties.publisherName
                                    PublisherType = $consumptionLine.properties.publisherType
                                    Quantity = $consumptionLine.properties.quantity
                                    ReservationId = $consumptionLine.properties.reservationId
                                    ReservationName = $consumptionLine.properties.reservationName
                                    ResourceGroup = $consumptionLine.properties.resourceGroup
                                    ResourceId = $consumptionLine.properties.instanceName
                                    ResourceLocation = $consumptionLine.properties.resourceLocation
                                    resourceLocationNormalized = $consumptionLine.properties.resourceLocationNormalized
                                    ServiceFamily = $consumptionLine.properties.serviceFamily
                                    SubscriptionId = $consumptionLine.properties.subscriptionGuid
                                    SubscriptionName = $consumptionLine.properties.subscriptionName
                                    Tags = $tags
                                    Term = $consumptionLine.properties.term
                                    UnitOfMeasure = $consumptionLine.properties.unitOfMeasure
                                    UnitPrice = $consumptionLine.properties.unitPrice
                                }            
                            }
                            $billingEntries += $billingEntry    
                        }
                    }    
                }
                while ($requestSuccess -and -not([string]::IsNullOrEmpty($consumption.nextLink)))
            
                if ($requestSuccess)
                {
                    "Generated $($billingEntries.Count) entries..."
                
                    "Uploading CSV to Storage"
                
                    $ci = [CultureInfo]::new([System.Threading.Thread]::CurrentThread.CurrentCulture.Name)
                    if ($ci.NumberFormat.NumberDecimalSeparator -ne '.')
                    {
                        "Current culture ($($ci.Name)) does not use . as decimal separator"    
                        $ci.NumberFormat.NumberDecimalSeparator = '.'
                        [System.Threading.Thread]::CurrentThread.CurrentCulture = $ci
                    }
                
                    $csvExportPath = "$targetStartDate-$($subscription.Id)-$consumptionMetric.csv"
            
                    $billingEntries | Export-Csv -Path $csvExportPath -NoTypeInformation    
            
                    $csvBlobName = $csvExportPath
                    $csvProperties = @{"ContentType" = "text/csv"};
                    Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force
                    
                    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                    "[$now] Uploaded $csvBlobName to Blob Storage..."
                
                    Remove-Item -Path $csvExportPath -Force
                
                    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                    "[$now] Removed $csvExportPath from local disk..."        
                }
                else
                {
                    $global:hadErrors = $true
                    $global:scopesWithErrors += $ScopeName
                    Write-Warning "Failed to get consumption data for subscription $($subscription.Name)..."
                }
            }
            elseif ($subscriptionQuotaID -in $CostDetailsSupportedQuotaIDs -or $consumptionAPIOption -eq "CostDetails")
            {
                "Starting cost details export process from $targetStartDate to $targetEndDate for subscription $($subscription.Name)..."
                Generate-CostDetails -ScopeId "/subscriptions/$($subscription.Id)" -ScopeName $subscription.Id
            }
            else
            {
                $global:hadErrors = $true
                $global:scopesWithErrors += $ScopeName
                Write-Warning "Subscription quota $subscriptionQuotaID not supported"
            }
        }    
    }
    else
    {
        if ($consumptionScope -eq "BillingAccount")
        {
            "Starting cost details export process from $targetStartDate to $targetEndDate for Billing Account ID $BillingAccountID..."
            Generate-CostDetails -ScopeId "/providers/Microsoft.Billing/billingAccounts/$BillingAccountID" -ScopeName $BillingAccountID.Replace(":","_")    
        }
        if ($consumptionScope -eq "BillingProfile")
        {
            "Starting cost details export process from $targetStartDate to $targetEndDate for Billing Account ID $BillingAccountID / Billing Profile ID $BillingProfileID ..."
            Generate-CostDetails -ScopeId "/providers/Microsoft.Billing/billingAccounts/$BillingAccountID/billingProfiles/$BillingProfileID" -ScopeName $BillingProfileID    
        }
    }    
}

if ($global:hadErrors)
{
    $scopesWithErrorsString = $global:scopesWithErrors -join ","
    throw "There were errors during the export process with the following scopes: $scopesWithErrorsString. Please check the output for details."
}