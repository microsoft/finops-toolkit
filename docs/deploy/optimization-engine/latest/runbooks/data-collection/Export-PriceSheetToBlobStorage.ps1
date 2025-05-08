param(
    [Parameter(Mandatory = $false)]
    [string] $BillingAccountID,

    [Parameter(Mandatory = $false)]
    [string] $BillingProfileID,

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName,

    [Parameter(Mandatory = $false)]
    [string] $billingPeriod, # YYYYMM format

    [Parameter(Mandatory = $false)]
    [string] $meterCategories, # comma-separated meter categories (for example, "Virtual Machines,Storage")

    [Parameter(Mandatory = $false)]
    [string] $meterRegions # comma-separated billing meter regions (for example, "EU North,EU West")
)

$ErrorActionPreference = "Stop"

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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_PriceSheetContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "pricesheetexports"
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

$consumptionOffsetDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_ConsumptionOffsetDays")
$meterCategoriesVar = Get-AutomationVariable -Name "AzureOptimization_PriceSheetMeterCategories" -ErrorAction SilentlyContinue
$meterRegionsVar = Get-AutomationVariable -Name "AzureOptimization_PriceSheetMeterRegions" -ErrorAction SilentlyContinue
$BillingAccountIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingAccountID" -ErrorAction SilentlyContinue
$BillingProfileIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingProfileID" -ErrorAction SilentlyContinue

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

# compute billing period

if ([string]::IsNullOrEmpty($billingPeriod))
{
    $billingPeriod = (Get-Date).Date.AddDays($consumptionOffsetDays * -1).ToString("yyyyMM")
}

$exportDate = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")

if ([string]::IsNullOrEmpty($BillingAccountID) -and -not([string]::IsNullOrEmpty($BillingAccountIDVar)))
{
    $BillingAccountID = $BillingAccountIDVar
}

if ([string]::IsNullOrEmpty($BillingProfileID) -and -not([string]::IsNullOrEmpty($BillingProfileIDVar)))
{
    $BillingProfileID = $BillingProfileIDVar
}

$mcaBillingAccountIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+):([A-Za-z0-9]+(-[A-Za-z0-9]+)+)_[0-9]{4}-[0-9]{2}-[0-9]{2}"
$mcaBillingProfileIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"

if ([string]::IsNullOrEmpty($BillingAccountID))
{
    throw "Billing Account ID undefined. Use either the AzureOptimization_BillingAccountID variable or the BillingAccountID parameter"
}
else {
    if ($BillingAccountID -match $mcaBillingAccountIdRegex)
    {
        if ([string]::IsNullOrEmpty($BillingProfileID))
        {
            throw "Billing Profile ID undefined for MCA. Use either the AzureOptimization_BillingProfileID variable or the BillingProfileID parameter"
        }
        if (-not($BillingProfileID -match $mcaBillingProfileIdRegex))
        {
            throw "Billing Profile ID does not follow pattern for MCA: ([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"
        }
    }
}

if (-not([string]::IsNullOrEmpty($meterCategoriesVar)))
{
    $meterCategories = $meterCategoriesVar
}

if (-not([string]::IsNullOrEmpty($meterRegionsVar)))
{
    $meterRegions = $meterRegionsVar
}

$meterCategoryFilters = $null
$meterRegionFilters = $null

if (-not([string]::IsNullOrEmpty($meterCategories)))
{
    $meterCategoryFilters = $meterCategories.Split(',')
}

if (-not([string]::IsNullOrEmpty($meterRegions)))
{
    $meterRegionFilters = $meterRegions.Split(',')
}

function Generate-Pricesheet {
    param (
        [string] $InputCSVPath,
        [string] $OutputCSVPath,
        [string] $HeaderLine
    )

    # header normalization between MCA and EA
    $headerConversion = @{
        'Meter ID' = "MeterID";
        meterId = "MeterID";
        'Meter name' = "MeterName";
        meterName = "MeterName";
        'Meter category' = "MeterCategory";
        meterCategory = "MeterCategory";
        'Meter sub-category' = "MeterSubCategory";
        meterSubCategory = "MeterSubCategory";
        'Meter region' = "MeterRegion";
        meterRegion = "MeterRegion";
        'Unit of measure' = "UnitOfMeasure";
        unitOfMeasure = "UnitOfMeasure";
        'Part number' = "PartNumber";
        'Unit price' = "UnitPrice";
        unitPrice = "UnitPrice";
        'Currency code' = "CurrencyCode";
        currency = "CurrencyCode";
        'Included quantity' = "IncludedQuantity";
        includedQuantity = "IncludedQuantity";
        'Offer Id' = "OfferId";
        Term = "Term";
        'Price type' = "PriceType";
        priceType = "PriceType"
    }

    $r = [IO.File]::OpenText($InputCSVPath)
    $w = [System.IO.StreamWriter]::new($OutputCSVPath)
    $lineCounter = 0
    while ($r.Peek() -ge 0) {
        $line = $r.ReadLine()
        $lineCounter++
        if ($lineCounter -eq $HeaderLine)
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

            if (-not($line -match "SubCategory"))
            {
                throw "Pricesheet format has changed at line $HeaderLine - $line"
            }

            Write-Output "New headers: $line"

            $w.WriteLine($line)
        }
        else
        {
            if ($lineCounter -gt $HeaderLine)
            {
                $categoryWriteLine = $categoryWriteLineDefault
                $regionWriteLine = $regionWriteLineDefault

                foreach ($meterCategory in $meterCategoryFilters)
                {
                    if ($line -match ",$meterCategory,")
                    {
                        $categoryWriteLine = $true
                        break
                    }
                }

                foreach ($meterRegion in $meterRegionFilters)
                {
                    if ($line -match ",$meterRegion,")
                    {
                        $regionWriteLine = $true
                        break
                    }
                }

                if ($categoryWriteLine -eq $true -and $regionWriteLine -eq $true)
                {
                    $w.WriteLine($line)
                }
            }
        }
    }
    $r.Dispose()
    $w.Close()

    $csvBlobName = [System.IO.Path]::GetFileName($OutputCSVPath)
    $csvProperties = @{"ContentType" = "text/csv"};
    Set-AzStorageBlobContent -File $OutputCSVPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

    Remove-Item -Path $InputCSVPath -Force

    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    Write-Output "[$now] Removed $InputCSVPath from local disk..."

    Remove-Item -Path $OutputCSVPath -Force

    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    Write-Output "[$now] Removed $OutputCSVPath from local disk..."
}

Write-Output "Starting pricesheet export process for $billingPeriod billing period for Billing Account $BillingAccountID..."

$MaxTries = 30 # The typical Retry-After is set to 20 seconds. We'll give 10 minutes overall to download the pricesheet report

if ($BillingAccountID -match $mcaBillingAccountIdRegex)
{
    $PriceSheetApiPath = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountID/billingProfiles/$BillingProfileID/providers/Microsoft.CostManagement/pricesheets/default/download?api-version=2023-03-01&format=csv"
    $result = Invoke-AzRestMethod -Path $PriceSheetApiPath -Method POST
}
else
{
    $PriceSheetApiPath = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountID/billingPeriods/$billingPeriod/providers/Microsoft.Consumption/pricesheets/download?api-version=2022-06-01&ln=en"
    $result = Invoke-AzRestMethod -Path $PriceSheetApiPath -Method GET
}

$requestResultPath = $result.Headers.Location.PathAndQuery
if ($result.StatusCode -in (200,202))
{
    $tries = 0
    $requestSuccess = $false

    Write-Output "Obtained pricesheet results endpoint: $requestResultPath..."

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
            Write-Output "Filtering data with meter categories $meterCategories and meter regions $meterRegions to $finalCsvExportPath..."

            $categoryWriteLineDefault = $true
            if ($meterCategoryFilters.Count -gt 0)
            {
                $categoryWriteLineDefault = $false
            }
            $regionWriteLineDefault = $true
            if ($meterRegionFilters.Count -gt 0)
            {
                $regionWriteLineDefault = $false
            }

            Write-Output "Defaulting to meter categories writes $($categoryWriteLineDefault) and meter regions writes $($regionWriteLineDefault)..."

            if ($BillingAccountID -match $mcaBillingAccountIdRegex)
            {
                Write-Output "Export is ready. Proceeding with ZIP download..."
                $downloadUrl = ($downloadResult.Content | ConvertFrom-Json).publishedEntity.properties.downloadUrl
                $zipExportPath = "$env:TEMP\pricesheet-$BillingProfileID-$exportDate.zip"
                $zipExpandPath = "$env:TEMP\pricesheet"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipExportPath
                Write-Output "Blob downloaded to $zipExportPath successfully."
                Expand-Archive -LiteralPath $zipExportPath -DestinationPath $zipExpandPath -Force
                Write-Output "Zip expanded to $zipExpandPath successfully."
                $csvFiles = Get-ChildItem -Path $zipExpandPath -Filter *.csv -Recurse
                foreach ($csvFile in $csvFiles)
                {
                    $csvExportPath = $csvFile.FullName
                    $finalCsvExportPath = "$env:TEMP\$($csvFile.Name)-final.csv"
                    Generate-Pricesheet -InputCSVPath $csvExportPath -OutputCSVPath $finalCsvExportPath -HeaderLine 1
                }
                Remove-Item -Path $zipExportPath -Force
                $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                Write-Output "[$now] Removed $zipExportPath from local disk..."
            }
            else
            {
                Write-Output "Export is ready. Proceeding with CSV download..."
                $downloadUrl = ($downloadResult.Content | ConvertFrom-Json).properties.downloadUrl
                $csvExportPath = "$env:TEMP\pricesheet-$billingPeriod-$BillingAccountID.csv"
                $finalCsvExportPath = "$env:TEMP\pricesheet-$billingPeriod-$BillingAccountID$($meterCategories.Replace(',',''))$($meterRegions.Replace(',',''))-$exportDate-final.csv"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $csvExportPath
                Write-Output "Blob downloaded to $csvExportPath successfully."
                Generate-Pricesheet -InputCSVPath $csvExportPath -OutputCSVPath $finalCsvExportPath -HeaderLine 3
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
            Write-Output "Got an unexpected response code: $($downloadResult.StatusCode)"
        }
    }
    while (-not($requestSuccess) -and $tries -lt $MaxTries)

    if ($tries -ge $MaxTries)
    {
        throw "Couldn't complete request before the alloted number of $MaxTries retries"
    }

    if (-not($requestSuccess))
    {
        throw "Error returned by the Download PriceSheet API. Status Code: $($downloadResult.StatusCode). Message: $($downloadResult.Content)"
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
        throw "Error returned by the Download PriceSheet API. Status Code: $($result.StatusCode). Message: $($result.Content)"
    }
    else
    {
        Write-Output "Request returned 204 No Content"
    }
}