# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates open data files and compiles contents into corresponding PowerShell functions.

    .PARAMETER Name
    Name of the data to build. Allowed = PricingUnits, Regions, ResourceTypes, Services. Default = * (all).

    .PARAMETER Data
    Indicates that data files should be generated. Only applies to resource types. Default = false, if -PowerShell is not specified.

    .PARAMETER PowerShell
    Indicates that PowerShell functions should be generated from data files. Default = true, unless -Data is specified.

    .PARAMETER Hubs
    Indicates that FinOps hubs KQL functions should be generated from data files. Default = true, unless -Data is specified.

    .PARAMETER All
    Indicates that all data files and PowerShell functions should be generated. Shortcut for -Data -PowerShell. Default = false.

    .PARAMETER Test
    Indicates that data tests should be run after the build completes. Default = false.

    .EXAMPLE
    ./Build-OpenData Services

    Generates a private Get-FinOpsServicesData PowerShell function from the contents of open-data/Services.csv.

    .EXAMPLE
    ./Build-OpenData -Data

    Generates data files for all applicable datasets.

    .EXAMPLE
    ./Build-OpenData -All

    Generates data files and PowerShell functions for all datasets.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-opendata
#>
Param(
    [Parameter(Position = 0)]
    [string]
    $Name = "*",

    [switch]
    $Data,

    [switch]
    $PowerShell,

    [switch]
    $Hubs,

    [switch]
    $All,

    [switch]
    $Test
)

if ($All)
{
    $Data = $PowerShell = $Hubs = $true
}
elseif (-not $Data -and -not $PowerShell -and -not $Hubs)
{
    $PowerShell = $true
}

# Some columns may have numbers and strings. Use the following list to force them to be handled as string.
$stringColumnNames = @('UnitOfMeasure')

function Write-Command($Command, $File)
{
    $columns = (Get-Content $File -TotalCount 1).Split(",") | ForEach-Object { $_.Trim('"') }
    $data = Import-Csv $File

    Write-Output "# Copyright (c) Microsoft Corporation."
    Write-Output "# Licensed under the MIT License."
    Write-Output ""
    Write-Output "function $Command"
    Write-Output "{"
    Write-Output "    param()"
    Write-Output "    return [PSCustomObject]@("

    $script:rowNum = 0
    $first = $true
    $data | ForEach-Object {
        $row = $_
        $script:rowNum++
        Write-Debug "Row $($script:rowNum) = '$($row.UnitOfMeasure)'"
        $props = $columns | ForEach-Object {
            $column = $_
            $value = $row.$column
            if ($value -eq '') { $value = $null }
            $quote = if ($value -match '^[\d\.]+$' -and -not ($stringColumnNames -contains $column)) { "" } else { "'" }
            return "$column = $quote$($value -replace "'", "''" -replace "’", "''")$quote;"
        }
        Write-Output "        $(if (-not $first) { ',' })[PSCustomObject]@{ $($props -join ' ') }"
        $first = $false
    }

    Write-Output "    )"
    Write-Output "}"
}

function Write-Test($DataType, $Command)
{
    Write-Output "# Copyright (c) Microsoft Corporation."
    Write-Output "# Licensed under the MIT License."
    Write-Output ""
    Write-Output "Describe '$Command' {"
    Write-Output "    It 'Should return same rows as the CSV file' {"
    Write-Output "        # Arrange"
    Write-Output "        . `"`$PSScriptRoot/../../Private/$Command.ps1`""
    Write-Output "        `$csv = Import-Csv `"`$PSScriptRoot/../../../open-data/$DataType.csv`""
    Write-Output ""
    Write-Output "        # Act"
    Write-Output "        `$cmd = $Command"
    Write-Output ""
    Write-Output "        # Assert"
    Write-Output "        `$cmd.Count | Should -Be `$csv.Count"
    Write-Output "    }"
    Write-Output "}"
}

function Write-KqlSplitFunction($Function, $Rows, $Columns)
{
    # Write header
    Write-Output "// Copyright (c) Microsoft Corporation."
    Write-Output "// Licensed under the MIT License."
    Write-Output ""
    Write-Output ".create-or-alter function "
    Write-Output "with (docstring = 'Return details about the specified ID.', folder = 'OpenData/Internal')"
    Write-Output "$Function(id: string) {"
    Write-Output "    dynamic({"
    
    $firstRow = $true
    $Rows | ForEach-Object {
        $row = $_
        $firstColumn = $true
        $props = $Columns | ForEach-Object {
            $column = $_
            $value = $row.$column
            if ($null -eq $value) { $value = '' }
            $stringColumn = (-not ($value -match '^([\d\.]+|true|false)$')) -or ($stringColumnNames -contains $column)
            if ($stringColumn) { $quote = '"' } else { $quote = '' }
            $escapingQuote = "$(if ($stringColumn -and $value.Contains('"')) { '@' })$quote"
            $line = "$(if (-not $firstColumn) { "$quote$column$quote`: " })$escapingQuote$($value -replace '"', '""')$quote"
            $firstColumn = $false
            return $line
        }
        Write-Output "        $(if (-not $firstRow) { ',' })$($props[0]): { $(($props | Select-Object -Skip 1) -join ', ') }"
        $firstRow = $false
    }
    
    Write-Output "    })[tolower(id)]"
    Write-Output "}"
}

function Write-KqlWrapperFunction($Function, $Parts)
{
    Write-Output "// $Function"
    Write-Output ".create-or-alter function "
    Write-Output "with (docstring = 'Return details about the specified ID.', folder = 'OpenData')"
    Write-Output "$Function(id: string) {"
    Write-Output "    coalesce($(($Parts | ForEach-Object { "$($_.Name)(id)" }) -join ', '))"
    Write-Output "}"
}

$hubsDir = "$PSScriptRoot/../templates/finops-hub/modules/scripts"
$psDir = "$PSScriptRoot/../powershell"
$srcDir = "$PSScriptRoot/../open-data"
$svgDir = "$PSScriptRoot/../../docs/svg"

if (($Name -eq "ResourceTypes" -or $Name -eq "*") -and $Data)
{
    # Pull resource types from the Azure app
    # $azureAppMetadataDir = '<devops>/_git/AzureUX-Mobile?path=/AzureMobile/AzureMobile.Core/Resources'
    # $token = Get-AzAccessToken -ResourceUrl (($azureAppMetadataDir -split '/')[0..2] -join '/')
    # @('Metadata.json', 'Metadata.resjson') | ForEach-Object {
    #     $file = $_
    #     Write-Verbose "Downloading $file from $azureAppMetadataDir..."
    #     Invoke-WebRequest `
    #         -Uri "$azureAppMetadataDir/$file" `
    #         -OutFile "$srcDir/$file" `
    #         -Headers @{ Authorization = "Bearer $($token.Token)" }
    # }

    # Internal icon paths
    $internalIconPath = "$PSScriptRoot/../../../portalfx/src/sdk/website/TypeScript/MsPortalImpl/Svg/Library"
    $internalIcons = @{
        BacklogPoly              = 'Polychromatic/Backlog.svg'
        CloudService             = 'Polychromatic/CloudService.svg'
        CommitPoly               = 'Polychromatic/Commit.svg'
        Controls                 = 'Polychromatic/Controls.svg'
        Cubes                    = 'Polychromatic/Cubes.svg'
        CloudUpload              = 'CloudUpload.svg'
        Database                 = 'Polychromatic/Database.svg'
        Globe                    = 'Polychromatic/Globe.svg'
        Grid                     = 'Polychromatic/Grid.svg'
        Key                      = 'Polychromatic/Key.svg'
        LogoMicrosoftSquares     = 'Logos/MicrosoftSquares.svg'
        Notification             = 'Polychromatic/Notification.svg'
        PolyApiManagement        = 'Polychromatic/ApiManagement.svg'
        PolyAppInsights          = 'Polychromatic/AppInsights.svg'
        PolyAutomation           = 'Polychromatic/Automation.svg'
        PolyAvailabilitySet      = 'Polychromatic/AvailabilitySet.svg'
        PolyBackup               = 'Polychromatic/Backup.svg'
        PolyCdn                  = 'Polychromatic/Cdn.svg'
        PolyCertificate          = 'Polychromatic/Certificate.svg'
        PolyCustomDomain         = 'Polychromatic/CustomDomain.svg'
        PolyDashboard            = 'Polychromatic/Dashboard.svg'
        PolyDiscs                = 'Polychromatic/Discs.svg'
        PolyExtensions           = 'Polychromatic/Extensions.svg'
        PolyGlobe                = 'Polychromatic/Globe.svg'
        PolyIpAddress            = 'Polychromatic/IpAddress.svg'
        PolyLoadBalancer         = 'Polychromatic/LoadBalancer.svg'
        PolyNetworkInterfaceCard = 'Polychromatic/NetworkInterfaceCard.svg'
        PolyLogAnalytics         = 'Polychromatic/LogAnalytics.svg'
        PolyLogDiagnostics       = 'Polychromatic/LogDiagnostics.svg'
        PolyProductionReadyDb    = 'Polychromatic/ProductionReadyDb.svg'
        PolyResourceGroup        = 'Polychromatic/ResourceGroup.svg'
        PolySqlDataBaseServer    = 'Polychromatic/SqlDataBaseServer.svg'
        PolySqlDatabase          = 'Polychromatic/SqlDatabase.svg'
        PolySupport              = 'Polychromatic/Support.svg'
        PolyTrafficManager       = 'Polychromatic/TrafficManager.svg'
        PolyVersions             = 'Polychromatic/Versions.svg'
        PolyVirtualNetwork       = 'Polychromatic/VirtualNetwork.svg'
        PolyWebHosting           = 'Polychromatic/WebHosting.svg'
        PolyWebSlots             = 'Polychromatic/WebSlots.svg'
        PolyWebTest              = 'Polychromatic/WebTest.svg'
        Storage                  = 'Polychromatic/Storage.svg'
        TeamProject              = 'Polychromatic/TeamProject.svg'
        VirtualMachine           = 'Polychromatic/VirtualMachine.svg'
        Website                  = 'Polychromatic/Website.svg'
    }

    # SVG CSS classes are defined in <portalfx>\src\SDK\Website\Less\MsPortalImpl\Base\Base.Images.less
    $svgCssClasses = @(
        @{ cssClass = "msportalfx-svg-placeholder"; fill = ""; },
        @{ cssClass = "msportalfx-svg-c01"; fill = "#ffffff"; },
        @{ cssClass = "msportalfx-svg-c02"; fill = "#e5e5e5"; },
        @{ cssClass = "msportalfx-svg-c03"; fill = "#a0a1a2"; },
        @{ cssClass = "msportalfx-svg-c04"; fill = "#7a7a7a"; },
        @{ cssClass = "msportalfx-svg-c05"; fill = "#3e3e3e"; },
        @{ cssClass = "msportalfx-svg-c06"; fill = "#1e1e1e"; },
        @{ cssClass = "msportalfx-svg-c07"; fill = "#0f0f0f"; },
        @{ cssClass = "msportalfx-svg-c08"; fill = "#ba141a"; },
        @{ cssClass = "msportalfx-svg-c09"; fill = "#dd5900"; },
        @{ cssClass = "msportalfx-svg-c10"; fill = "#ff8c00"; },
        @{ cssClass = "msportalfx-svg-c11"; fill = "#fcd116"; },
        @{ cssClass = "msportalfx-svg-c12"; fill = "#fee087"; },
        @{ cssClass = "msportalfx-svg-c13"; fill = "#b8d432"; },
        @{ cssClass = "msportalfx-svg-c14"; fill = "#7fba00"; },
        @{ cssClass = "msportalfx-svg-c15"; fill = "#59b4d9"; },
        @{ cssClass = "msportalfx-svg-c16"; fill = "#3999c6"; },
        @{ cssClass = "msportalfx-svg-c17"; fill = "#804998"; },
        @{ cssClass = "msportalfx-svg-c18"; fill = "#ec008c"; },
        @{ cssClass = "msportalfx-svg-c19"; fill = "#0072c6"; },
        @{ cssClass = "msportalfx-svg-c20"; fill = "#68217a"; },
        @{ cssClass = "msportalfx-svg-c21"; fill = "#00188f"; },
        @{ cssClass = "msportalfx-svg-c22"; fill = "#e81123"; },
        @{ cssClass = "msportalfx-svg-c97"; fill = "#ffB900"; },
        @{ cssClass = "msportalfx-svg-c98"; fill = "#00a4ef"; },
        @{ cssClass = "msportalfx-svg-c99"; fill = "#f25022"; }
    )

    # The following link was copied from the Azure mobile app @ <devops>/_git/AzureUX-Mobile?path=/AzureMobile/AzureMobile.Core/Resources/Initialize-AzureMobileMetadata.ps1
    $azurePortalMetadata = 'https://rc.portal.azure.com/api/mobilemetadata?api-version=12-01-2021'
    $tempMetadata = New-TemporaryFile
    Write-Verbose "Downloading metadata from $azurePortalMetadata..."
    Invoke-WebRequest -Uri $azurePortalMetadata -OutFile $tempMetadata
    Write-Verbose "Extracting images, CSV, and JSON from $tempMetadata..."
    $metadataJson = Get-Content $tempMetadata -Raw | ConvertFrom-Json -Depth 100
    $overrides = Get-Content "$srcDir/ResourceTypes.Overrides.json" -Raw | ConvertFrom-Json -Depth 5
    $newTypes = @{}
    ($metadataJson.assets + @(@{ addOverrides = $true })) | ForEach-Object {
        $asset = $_
        $defaultIcon = (Get-Content "$svgDir/microsoft.resources/resources.svg" -Raw)

        function processResourceType($resourceType, $asset, $override)
        {
            # Clean and save SVG
            if ($override.icon)
            {
                if ($override.icon -eq $asset.icon) { Write-Warning "Remove redundant icon override for $resourceType" }
                if ($asset.icon -and $override.icon -ne $asset.icon -and (-not $override.originalIcon -or $override.originalIcon -ne $asset.icon)) { Write-Verbose "Overriding icon for $resourceType @ file:///$((Join-Path $svgDir $resourceType) -replace '\\', '/').svg" }
            }
            elseif (-not $asset.icon)
            {
                $oldIcon = Get-Content "$svgDir/$resourceType.svg" -Raw
                if ($oldIcon)
                {
                    Write-Warning "Icon no longer available; using old icon for $resourceType"
                }
                else
                {
                    Write-Warning "Using fallback cube icon for $resourceType"
                }
            }
            elseif ((-not $override.icon) -and $asset.icon.type -ne 'Custom' -and $asset.icon.type -ne 'PolyResourceDefault')
            {
                # Check for local internal icon
                $localInternalIconPath = "$internalIconPath/$($internalIcons[$asset.icon.type])"
                if ($localInternalIconPath.EndsWith('.svg'))
                {
                    if (Get-Item $localInternalIconPath)
                    { 
                        $internalIcon = Get-Content $localInternalIconPath -Raw 
                    }
                    else
                    {
                        Write-Warning "Internal $($asset.icon.type) icon not found"
                    }
                }

                if ($oldIcon -and ($oldIcon -ne $defaultIcon))
                {
                    Write-Warning "Resource uses internal $($asset.icon.type) icon; using old icon for $resourceType"
                }
                elseif (-not $internalIcon)
                {
                    Write-Warning "Resource uses internal $($asset.icon.type) icon; using default icon for $resourceType"
                }
            }
            $icon = $override.icon ?? $asset.icon.data ?? $internalIcon ?? $oldIcon ?? $defaultIcon
            if ($icon)
            {
                # Replace SVG classes with their fill equivalents
                $svgCssClasses | ForEach-Object { $icon = $icon.Replace("class='" + ($_.cssClass) + "'", "fill='$($_.fill)'").Replace(" class=''", "").Replace(" fill=''", ""); }
                $icon = $icon.Replace('"', "'")
                $icon = $icon.Replace("<stop stop-color", "<stop offset='0' stop-color")
                $icon = $icon.Replace("class=' fxs-portal-svg'", "")
                $icon = $icon.Replace("class='fxs-portal-svg'", "")
                $icon = $icon.Replace("class=""fxs-portal-svg""", "")

                # Remove unnecessary properties/tags and switch opacity to fill-opacity (ffimg bug)
                $icon = ($icon.Replace(" opacity=", " fill-opacity=") -replace ' xmlns:svg=', ' xmlns=' -replace " (focusable|role|xmlns:[^=]+)='[^']+'", "") -replace "<title>[^<]*</title>", ""

                # Replace clip paths that change often
                $icon = $icon -replace ' clip-path=''url\(#([^\)]+)', " clip-path='url(#$resourceType"
                $icon = $icon -replace '<clipPath id=''([^'']+)', "<clipPath id='$resourceType"

                # Save SVG to file
                $resourceTypeParent = $resourceType -split '/'
                $resourceTypeParent = $resourceTypeParent[0..($resourceTypeParent.Length - 2)] -join '/'
                & $PSScriptRoot/New-Directory "$svgDir/$resourceTypeParent"
                $icon | Out-File "$svgDir/$resourceType.svg" -Encoding utf8
            }

            $isPreview = ($asset.singularDisplayName + $asset.pluralDisplayName + $asset.lowerSingularDisplayName + $asset.lowerPluralDisplayName) -match 'preview'
            function noPreview($name) { return ($name -replace ' *\(preview\) *$', '' -replace ' *\| *preview *$', '').Trim() }
            function logOverrides($knownOld, $newVal, $oldVal, $valType)
            {
                if (-not $newVal -or -not $oldVal)
                {
                    return
                }
                elseif ($newVal -ceq $oldVal)
                {
                    # Override is the same as the original; should remove the override config
                    Write-Warning "Remove redundant $resourceType $valType '$($oldVal)'"
                }
                elseif ($newVal -eq $oldVal)
                {
                    # Do nothing; ignore case fixes
                    return
                }
                elseif (-not $knownOld -or $knownOld -ne $oldVal)
                {
                    # Unexpected overrides should be verified
                    Write-Warning "Overriding $resourceType $valType '$oldVal' → '$newVal'"
                }
            }
            logOverrides $override.originalSingular      $override.singular      $asset.singularDisplayName      'singular display name'
            logOverrides $override.originalPlural        $override.plural        $asset.pluralDisplayName        'plural display name'
            logOverrides $override.originalLowerSingular $override.lowerSingular $asset.lowerSingularDisplayName 'lower singular display name'
            logOverrides $override.originalLowerPlural   $override.lowerPlural   $asset.lowerPluralDisplayName   'lower plural display name'
            
            [array]$links = $asset.links | Select-Object -Property title, @{Name = 'uri'; Expression = { $_.uri.Replace('/en-us/', '/') } }
            $typeInfo = [PSCustomObject]@{
                ResourceType             = $resourceType.ToLower()
                SingularDisplayName      = noPreview ($override.singular ?? $asset.singularDisplayName)
                PluralDisplayName        = noPreview ($override.plural ?? $asset.pluralDisplayName)
                LowerSingularDisplayName = noPreview ($override.lowerSingular ?? $asset.lowerSingularDisplayName ?? $override.singular ?? $asset.singularDisplayName)
                LowerPluralDisplayName   = noPreview ($override.lowerPlural ?? $asset.lowerPluralDisplayName ?? $override.plural ?? $asset.pluralDisplayName)
                IsPreview                = $isPreview
                Description              = ($asset.description ?? '') -replace '[\n\r]', ' ' -replace '  *', ' ' ?? $null
                Icon                     = $icon ? "https://microsoft.github.io/finops-toolkit/svg/$resourceType.svg" : $null
                Links                    = $links
                Updated                  = [datetime]::Now.ToUniversalTime().ToString('yyyy-MM-dd')
            }

            # Warn if names are missing
            if ($asset.resourceType -and (-not $typeInfo.SingularDisplayName -or -not $typeInfo.PluralDisplayName -or -not $typeInfo.LowerSingularDisplayName -or -not $typeInfo.LowerPluralDisplayName))
            {
                Write-Warning "Missing display name for $($resourceType): $($typeInfo | ConvertTo-Json -Depth 10)"
            }

            # Write output
            return $typeInfo
        }

        if ($asset.addOverrides)
        {
            Write-Host "Adding $($overrides.Count) overrides..."
            $overrides | ForEach-Object {
                if (-not $_.singular -or -not $_.plural -or -not $_.icon)
                {
                    Write-Information "Skipping $($_.type) override"
                    return
                }
                $newTypes | Add-Member -MemberType NoteProperty -Name $_.type -Value (processResourceType $_.type @{} $_) -Force
            }
        }
        elseif ($asset.resourceType.resourceTypeName.ToLower().StartsWith('private.') `
                -or $asset.resourceType.resourceTypeName.ToLower().StartsWith('providers.test') `
                -or $asset.resourceType.resourceTypeName.ToLower() -contains '/browse')
        {
            # Skip private and test resource types
            Write-Warning "Skipping $($asset.resourceType.resourceTypeName)..."
            return
        }
        else
        {
            $resourceType = $asset.resourceType.resourceTypeName
            $resourceType = $resourceType.ToLower()

            if (-not $asset -or -not $resourceType -or -not $asset.resourceType.resourceTypeName -or -not $asset.singularDisplayName)
            {
                Write-Warning "Skipping $resourceType..."
                return
            }

            # Look for override and remove from array
            $override = $overrides | Where-Object { $_.type.ToLower() -eq $resourceType }
            if ($override)
            {
                $overrides = $overrides | Where-Object { $_.type.ToLower() -ne $resourceType }
            }

            $newTypes | Add-Member -MemberType NoteProperty -Name $resourceType -Value (processResourceType $resourceType $asset $override) -Force
        }
    }
    Write-Host "Found $($newTypes.Keys.Count) portal resource types"

    # Update resource types
    $updatedTypes = @()
    $finalTypes = Import-Csv "$srcDir/ResourceTypes.csv" -Encoding utf8 | ForEach-Object {
        $row = $_
        $newTypes[$row.ResourceType].PSObject.Properties | ForEach-Object {
            $prop = $_
            if ($null -ne $prop.Name)
            {
                $row | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
            }
        }
        $updatedTypes += $row.ResourceType
        return $row
    }
    Write-Host "Updated $updateCount existing resource types"

    # Add new resource types
    $updatedTypes | ForEach-Object { $newTypes.Remove($_) }
    $finalTypes += $newTypes.Values

    # Sort and save file
    $finalTypes `
    | Sort-Object -Property ResourceType `
    | Export-Csv "$srcDir/ResourceTypes.csv" -UseQuotes Always -NoTypeInformation -Encoding utf8
}

# Generate PowerShell functions from data files
if ($PowerShell)
{
    # Loop thru all datasets
    Get-ChildItem "$srcDir/*.csv" `
    | Where-Object { $_.Name -like "$Name.csv" }
    | ForEach-Object {
        $file = $_
        $dataType = $file.BaseName
        $command = "Get-OpenData$($dataType.TrimEnd('s'))"
    
        Write-Verbose "Generating $command from $dataType.csv..."
        Write-Command -Command $command -File $file      | Out-File "$psDir/Private/$command.ps1"          -Encoding ascii -Append:$false
        Write-Test -DataType $dataType -Command $command | Out-File "$psDir/Tests/Unit/$command.Tests.ps1" -Encoding ascii -Append:$false
    }
}

# Test the generated PowerShell functions
if ($Test)
{
    & "$PSScriptRoot/Test-PowerShell.ps1" -Unit -Integration -Data
}

# Generate Hubs KQL functions from data files
if ($Hubs)
{
    $outFile = "$hubsDir/OpenDataFunctions.kql"
    $rowsPerFile = 500

    # Write header
    Write-Output "// Copyright (c) Microsoft Corporation." | Out-File $outFile -Encoding ascii -Append:$false
    Write-Output "// Licensed under the MIT License."      | Out-File $outFile -Encoding ascii -Append

    # Constraints
    $filesToUse = $(
        'ResourceTypes'
    )
    $columnsToKeep = $(
        'ResourceType',
        'SingularDisplayName'
    )
    
    # Loop thru all datasets
    Get-ChildItem "$srcDir/*.csv" `
    | Where-Object { $_.Name -like "$Name.csv" -and $filesToUse -contains $_.BaseName }
    | ForEach-Object {
        $file = $_
        $dataType = $file.BaseName
        $function = ($dataType -creplace '([a-z])([A-Z])', '$1_$2').ToLower().TrimEnd('s')
    
        Write-Verbose "Reading $dataType.csv..."
        $columns = (Get-Content $File -TotalCount 1).Split(",") | ForEach-Object { $_.Trim('"') } `
        | Where-Object { $ColumnsToKeep -contains $_ }
        $rows = Import-Csv $File
        
        # Split the array into groups
        $parts = @()
        for ($i = 0; $i -lt $rows.Count; $i += $rowsPerFile)
        {
            $parts += @{ Name = "_$($function)_$($parts.Count+1)"; Rows = $rows[$i..([math]::Min($i + $rowsPerFile - 1, $rows.Count - 1))] }
        }
        Write-Verbose "  $($rows.Count) rows split across $($parts.Count) files"

        # Write the wrapper function
        Write-Verbose "Generating KQL $function() from $dataType.csv..."
        Write-Output "" | Out-File $outFile -Encoding ascii -Append
        Write-KqlWrapperFunction -Function $function -Parts $parts `
        | Out-File $outFile -Encoding ascii -Append

        # Write the internal functions
        0..($parts.Count - 1) | ForEach-Object {
            $index = $_
            $part = $parts[$index]
            $splitFunction = $part.Name
            $splitFile = $outFile.Replace('.kql', "$splitFunction.kql")
            Write-Verbose "Generating KQL $splitFunction()..."
            Write-KqlSplitFunction -Function $splitFunction -Rows $part.Rows -Columns $columns `
            | Out-File $splitFile -Encoding ascii -Append:$false
        }
    }
}

<# TODO: Integrate the following script to revert SVG files with nonfunctional changes
(git diff --name-only) `
| Where-Object { $_ -match '^docs/svg/([^/]+/)+[^\.]+\.svg$' } `
| ForEach-Object {
    $file = $_
    $diff = git diff -- $file
    $changes = $diff -split "`n" `
    | Where-Object { $_ -match '^\+|^\-' } ` # Remove lines that are not changes
    | Where-Object { $_ -notmatch '^\+\+\+|^\-\-\-' } # Remove the diff metadata lines
    # Check if all changes are GUID changes
    $hasFunctionalChanges = $true
    foreach ($line in $changes)
    {
        if (
            $line -notmatch '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' `
            -and $line -notmatch '^\+\s*$' `
            -and $line -notmatch '^\-\s*$' `
        )
        {
            $hasFunctionalChanges = $true
            break
        }
    }
    if (-not $hasFunctionalChanges)
    {
        Write-Host "Reverting $file"
        git checkout -- $file
    }
}
#>
