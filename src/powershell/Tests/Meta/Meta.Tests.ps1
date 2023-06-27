BeforeDiscovery {
    $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
    $filesToInclude = 'FinOpsToolkit.psm1'
    $files = Get-ChildItem -Path $rootPath -Recurse -Include $filesToInclude
}

Describe 'Style tests - [<_>]' -ForEach $files.FullName {
    BeforeDiscovery {
        $rules = Get-ScriptAnalyzerRule
    }

    BeforeAll {
        $file = $_

        function Write-PsScriptAnalyzerWarning
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory = $true)]
                [string]
                $FileName,

                [Parameter(Mandatory = $true)]
                [string]
                $RuleName,

                [Parameter(Mandatory = $true)]
                [object[]]
                $PssaRuleOutput
            )

            foreach ($rule in $PssaRuleOutput)
            {
                Write-Warning -Message "$FileName (Line $($rule.Line)): $($rule.Message)"
            }
        }
    }

    It 'Should pass rule [<_>]' -ForEach $rules.RuleName {
        $result = Invoke-ScriptAnalyzer -Path $file -IncludeRule $_

        if ($null -ne $result)
        {
            Write-PsScriptAnalyzerWarning -FileName $file -RuleName $_ -PssaRuleOutput $result
        }

        $result | Should -BeNullOrEmpty
    }   
}
