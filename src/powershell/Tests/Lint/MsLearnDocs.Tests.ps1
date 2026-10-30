# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeDiscovery {
    $docsPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'docs-mslearn'
    $markdownFiles = Get-ChildItem -Path $docsPath -Recurse -Filter '*.md' -File
}

Describe 'Microsoft Learn docs - [<_.Name>]' -ForEach $markdownFiles {
    BeforeAll {
        $file = $_
        $content = Get-Content -Path $file.FullName -Raw

        # Extract frontmatter (content between first pair of ---)
        $frontmatterMatch = [regex]::Match($content, '^---\r?\n([\s\S]*?)\r?\n---')
        $hasFrontmatter = $frontmatterMatch.Success
        $frontmatter = if ($hasFrontmatter) { $frontmatterMatch.Groups[1].Value } else { '' }

        # Extract ms.date value
        $msDateMatch = [regex]::Match($frontmatter, '^ms\.date:\s*(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $hasMsDate = $msDateMatch.Success
        $msDateValue = if ($hasMsDate) { $msDateMatch.Groups[1].Value.Trim() } else { '' }

        # Helper function to parse date
        function Test-MsDateValid {
            param([string]$DateString)
            try {
                $null = [datetime]::ParseExact($DateString, 'MM/dd/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
                return $true
            } catch {
                return $false
            }
        }

        function Get-MsDateParsed {
            param([string]$DateString)
            try {
                return [datetime]::ParseExact($DateString, 'MM/dd/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                return $null
            }
        }
    }

    It 'Should have YAML frontmatter' {
        $hasFrontmatter | Should -BeTrue -Because "Microsoft Learn docs require YAML frontmatter"
    }

    It 'Should have ms.date field' {
        $hasMsDate | Should -BeTrue -Because "Microsoft Learn docs require an ms.date field in frontmatter"
    }

    It 'Should have ms.date in MM/DD/YYYY format' {
        if (-not $hasMsDate) {
            Set-ItResult -Skipped -Because "ms.date field is missing"
            return
        }

        # Validate format: MM/DD/YYYY
        $msDateValue | Should -Match '^\d{2}/\d{2}/\d{4}$' -Because "ms.date must be in MM/DD/YYYY format (found: $msDateValue)"
    }

    It 'Should have a valid ms.date value' {
        if (-not $hasMsDate) {
            Set-ItResult -Skipped -Because "ms.date field is missing"
            return
        }

        # Try to parse the date
        $isValidDate = Test-MsDateValid -DateString $msDateValue
        $isValidDate | Should -BeTrue -Because "ms.date must be a valid date (found: $msDateValue)"
    }

    It 'Should not have ms.date in the future' {
        if (-not $hasMsDate) {
            Set-ItResult -Skipped -Because "ms.date field is missing"
            return
        }

        $parsedDate = Get-MsDateParsed -DateString $msDateValue
        if (-not $parsedDate) {
            Set-ItResult -Skipped -Because "ms.date is not a valid date"
            return
        }

        $parsedDate | Should -BeLessOrEqual (Get-Date) -Because "ms.date should not be in the future"
    }

    It 'Should have ms.date within reasonable range (after 2020)' {
        if (-not $hasMsDate) {
            Set-ItResult -Skipped -Because "ms.date field is missing"
            return
        }

        $parsedDate = Get-MsDateParsed -DateString $msDateValue
        if (-not $parsedDate) {
            Set-ItResult -Skipped -Because "ms.date is not a valid date"
            return
        }

        $minDate = [datetime]::new(2020, 1, 1)
        $parsedDate | Should -BeGreaterOrEqual $minDate -Because "ms.date seems too old (FinOps toolkit started in 2020)"
    }
}
