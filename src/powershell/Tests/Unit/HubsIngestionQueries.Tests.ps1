# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'HubsIngestionQueries' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $queriesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries'
        $schemasPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/schemas'
        $schemaFileNames = @(Get-ChildItem -Path $schemasPath -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        # Convert FileInfo to hashtables so Pester -ForEach iterates correctly
        $queryFiles = @(Get-ChildItem -Path $queriesPath -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; BaseName = $_.BaseName; SchemaFileNames = $schemaFileNames }
            })
        $schemaFiles = @(Get-ChildItem -Path $schemasPath -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; BaseName = $_.BaseName }
            })
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $queriesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries'
        $schemasPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/schemas'
        $queryFileCount = @(Get-ChildItem -Path $queriesPath -Filter '*.json' -ErrorAction SilentlyContinue).Count
        $schemaFileCount = @(Get-ChildItem -Path $schemasPath -Filter '*.json' -ErrorAction SilentlyContinue).Count
        $knownEngines = @('ResourceGraph')
        $requiredQueryFields = @('dataset', 'provider', 'query', 'queryEngine', 'scope', 'source', 'type', 'version')

        # Derive known groups from Recommendations/app.bicep parameters.
        # Non-core groups need a corresponding "enable{Group}Recommendations" bool parameter in app.bicep.
        $appBicepPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/app.bicep'
        $appBicepContent = Get-Content -Path $appBicepPath -Raw
        $knownGroups = @('core') + @([regex]::Matches($appBicepContent, 'param enable(\w+)Recommendations bool') | ForEach-Object { $_.Groups[1].Value.ToLower() })
    }

    Context 'Query files' {

        It 'Should have at least one query file' {
            $queryFileCount | Should -BeGreaterThan 0
        }

        It 'Should be valid JSON: <Name>' -ForEach $queryFiles {
            { Get-Content -Path $FullName -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have all required fields: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($field in $requiredQueryFields)
            {
                $json.PSObject.Properties.Name | Should -Contain $field -Because "query file '$Name' is missing required field '$field'"
            }
        }

        It 'Should not have empty fields: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($field in $requiredQueryFields)
            {
                $json.$field | Should -Not -BeNullOrEmpty -Because "field '$field' in '$Name' should not be empty"
            }
        }

        It 'Should use a known query engine: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.queryEngine | Should -BeIn $knownEngines -Because "queryEngine '$($json.queryEngine)' in '$Name' is not a known engine ($($knownEngines -join ', '))"
        }

        It 'Should match naming convention: <Name>' -ForEach $queryFiles {
            $Name | Should -Match '^[A-Za-z]+-[A-Za-z]+-[A-Za-z0-9]+\.json$' -Because "query file '$Name' should follow the '{Dataset}-{Provider}-{Name}.json' naming convention"
        }

        It 'Should use a known query group: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $group = if ($json.PSObject.Properties['group'] -and $json.group) { $json.group } else { 'core' }
            $group | Should -BeIn $knownGroups -Because "query group '$group' in '$Name' is not a known group ($($knownGroups -join ', ')). Add the group to Build-HubIngestionQueries.ps1 `$groupConfig` and Recommendations/app.bicep before using it."
        }

        It 'Should be consistent with dataset field: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $expectedPrefix = "$($json.dataset)-"
            $BaseName | Should -BeLike "$expectedPrefix*" -Because "file name '$Name' should start with dataset '$($json.dataset)-'"
        }
    }

    Context 'Schema files' {

        It 'Should have at least one schema file' {
            $schemaFileCount | Should -BeGreaterThan 0
        }

        It 'Should be valid JSON: <Name>' -ForEach $schemaFiles {
            { Get-Content -Path $FullName -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have a translator property: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'translator'
        }

        It 'Should have translator mappings: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.translator.PSObject.Properties.Name | Should -Contain 'mappings'
            $json.translator.mappings.Count | Should -BeGreaterThan 0
        }

        It 'Should be TabularTranslator type: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.translator.type | Should -Be 'TabularTranslator'
        }

        It 'Should have source and sink in mappings: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($mapping in $json.translator.mappings)
            {
                $mapping.PSObject.Properties.Name | Should -Contain 'source' -Because 'each mapping needs a source'
                $mapping.PSObject.Properties.Name | Should -Contain 'sink' -Because 'each mapping needs a sink'
                $mapping.source.path | Should -Not -BeNullOrEmpty -Because 'source path should not be empty'
                $mapping.sink.path | Should -Not -BeNullOrEmpty -Because 'sink path should not be empty'
            }
        }
    }

    Context 'Query-to-schema consistency' {

        It 'Should have a matching schema file: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $expectedSchemaName = "$($json.dataset.ToLower())_$($json.version).json"
            $SchemaFileNames | Should -Contain $expectedSchemaName -Because "query '$Name' references dataset '$($json.dataset)' version '$($json.version)' but no schema file '$expectedSchemaName' exists"
        }
    }

    Context 'Bicep compilation' {

        It 'finops-hub template should compile without errors' {
            $mainBicep = Join-Path $repoRoot 'src/templates/finops-hub/main.bicep'
            if (Get-Command 'bicep' -ErrorAction SilentlyContinue)
            {
                $result = bicep build $mainBicep --stdout 2>&1
                $LASTEXITCODE | Should -Be 0 -Because "Bicep compilation failed: $($result | Out-String)"
            }
            else
            {
                Set-ItResult -Skipped -Because 'bicep CLI not found'
            }
        }
    }
}
