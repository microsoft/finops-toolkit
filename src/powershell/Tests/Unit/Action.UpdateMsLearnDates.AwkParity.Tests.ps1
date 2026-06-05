# Parity tests asserting that the awk implementation of strip_frontmatter() in
# .github/workflows/update-mslearn-dates.yml produces output equivalent to the
# PowerShell Get-DocsArticleBody function in src/scripts/Publish-Toolkit.ps1.
#
# The two implementations must agree on equivalence classes: any two inputs
# that pwsh treats as the same body must also be treated the same by awk, and
# vice versa. Otherwise the workflow and the publish-time docs comparison can
# disagree on what counts as a metadata-only change.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/update-mslearn-dates.yml'
    $script:PublishScript = Join-Path $script:RepoRoot 'src/scripts/Publish-Toolkit.ps1'

    $script:AwkAvailable = $null -ne (Get-Command awk -ErrorAction SilentlyContinue)

    # Extract Get-DocsArticleBody via AST (cannot dot-source Publish-Toolkit.ps1
    # because it has top-level executable code that triggers a publish run).
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:PublishScript, [ref]$tokens, [ref]$errors)
    $funcAst = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-DocsArticleBody'
    }, $true) | Select-Object -First 1
    . ([scriptblock]::Create($funcAst.Extent.Text))

    # Extract the strip_frontmatter awk script from the workflow YAML and write
    # it to a temp file we can pass to `awk -f`. The pattern grabs everything
    # between the single quotes of the `awk '...'` invocation inside
    # strip_frontmatter().
    $workflowContent = Get-Content -Raw -Path $script:WorkflowPath
    $pattern = "(?ms)strip_frontmatter\(\)\s*\{\s*awk\s*'(.*?)'\s*\}"
    $match = [regex]::Match($workflowContent, $pattern)
    if (-not $match.Success)
    {
        throw "Could not extract strip_frontmatter awk script from $script:WorkflowPath"
    }
    $script:AwkScript = $match.Groups[1].Value
    $script:AwkScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("strip_frontmatter_{0}.awk" -f ([guid]::NewGuid().ToString('N')))
    Set-Content -Path $script:AwkScriptPath -Value $script:AwkScript -NoNewline

    function script:Invoke-AwkStrip([string]$content)
    {
        # Use a temp input file to preserve byte-exact content including CRLFs
        # and trailing-newline differences. Pwsh on macOS/Linux native here.
        $inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("awk_in_{0}.txt" -f ([guid]::NewGuid().ToString('N')))
        try
        {
            [System.IO.File]::WriteAllText($inputPath, $content)
            $result = & awk -f $script:AwkScriptPath $inputPath 2>&1
            if ($LASTEXITCODE -ne 0)
            {
                throw "awk exited ${LASTEXITCODE}: $result"
            }
            return ($result -join "`n")
        }
        finally
        {
            Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
        }
    }

    # Equivalence-class fixtures. Inputs within a class must all produce the
    # same normalized body. Inputs across classes must produce distinct bodies.
    $script:Classes = @{
        'ms.date and ignore-only edit' = @(
            @"
---
title: Sample
ms.date: 01/01/2025
---
# Heading

Body paragraph.
"@,
            @"
---
title: Sample
ms.date: 12/31/2099
---
# Heading

Body paragraph.
"@,
            @"
---
title: Sample
ms.date: 01/01/2025
---
<!-- markdownlint-disable-next-line MD025 -->
# Heading

Body paragraph.
"@,
            @"
---
title: Sample
ms.date: 01/01/2025
---
<!-- prettier-ignore-start -->
# Heading

Body paragraph.
<!-- prettier-ignore-end -->
"@,
            # Trailing whitespace per line and an extra blank line.
            "---`ntitle: Sample`nms.date: 01/01/2025`n---`n# Heading   `n`n`nBody paragraph.   `n",
            # CRLF version of the same content.
            "---`r`ntitle: Sample`r`nms.date: 01/01/2025`r`n---`r`n# Heading`r`n`r`nBody paragraph.`r`n"
        )

        'frontmatter-only file (and whitespace-only body)' = @(
            @"
---
title: Sample
ms.date: 01/01/2025
---
"@,
            @"
---
title: Sample
ms.date: 12/31/2099
---
"@,
            "---`ntitle: WSOnly`n---`n   `n`n   `n",
            "---`ntitle: WSOnly`n---`n",
            "---`ntitle: WSOnly`n---"
        )

        'body text actually changed' = @(
            @"
---
title: Sample
---
# Heading

Different body content.
"@
        )

        'fence with surrounding whitespace' = @(
            "   ---   `ntitle: Y`nms.date: 01/01/2025`n   ---   `nFence-tolerance content.`n",
            "---`ntitle: Y`nms.date: 12/31/2099`n---`nFence-tolerance content.`n",
            "   ---`r`ntitle: Y`r`nms.date: 02/02/2026`r`n---   `r`nFence-tolerance content.`r`n"
        )

        'no-closing-fence files are body-equivalent only when bytes match' = @(
            @"
---
title: NoFence
ms.date: 01/01/2025
# missing closing fence
Some content here.
"@
        )

        'no-closing-fence with different metadata is a body change' = @(
            @"
---
title: NoFence
ms.date: 12/31/2099
# missing closing fence
Some content here.
"@
        )

        'extra leading blank lines in body' = @(
            "---`ntitle: X`n---`n`n`nReal content.`n",
            "---`ntitle: X`n---`nReal content.`n"
        )
    }

    # Build a flat list of (className, input) pairs.
    $script:Pairs = @()
    foreach ($className in $script:Classes.Keys)
    {
        foreach ($input in $script:Classes[$className])
        {
            $script:Pairs += [pscustomobject]@{
                Class = $className
                Input = $input
            }
        }
    }
}

AfterAll {
    if ($script:AwkScriptPath -and (Test-Path -LiteralPath $script:AwkScriptPath))
    {
        Remove-Item -LiteralPath $script:AwkScriptPath -ErrorAction SilentlyContinue
    }
}

Describe 'strip_frontmatter awk and Get-DocsArticleBody parity' {

    Context 'PowerShell within-class agreement' {
        It 'PowerShell collapses each equivalence class to a single normalized form' {
            foreach ($className in $script:Classes.Keys)
            {
                $bodies = $script:Classes[$className] | ForEach-Object { Get-DocsArticleBody $_ }
                $unique = $bodies | Select-Object -Unique
                $unique.Count | Should -Be 1 -Because "class '$className' should normalize to one body, got: $($unique -join ' || ')"
            }
        }

        It 'PowerShell produces distinct bodies for distinct equivalence classes' {
            $reps = @{}
            foreach ($className in $script:Classes.Keys)
            {
                $reps[$className] = Get-DocsArticleBody ($script:Classes[$className][0])
            }
            $values = $reps.Values | Select-Object -Unique
            $values.Count | Should -Be $reps.Count -Because "distinct classes should normalize differently: $($reps | Out-String)"
        }
    }

    Context 'awk and PowerShell agree on equivalence classes' -Skip:($null -eq (Get-Command awk -ErrorAction SilentlyContinue)) {
        It 'awk within-class agreement matches PowerShell' {
            foreach ($className in $script:Classes.Keys)
            {
                $bodies = $script:Classes[$className] | ForEach-Object { Invoke-AwkStrip $_ }
                $unique = $bodies | Select-Object -Unique
                $unique.Count | Should -Be 1 -Because "awk should collapse class '$className' to one body, got: $($unique -join ' || ')"
            }
        }

        It 'awk produces distinct bodies for distinct equivalence classes' {
            $reps = @{}
            foreach ($className in $script:Classes.Keys)
            {
                $reps[$className] = Invoke-AwkStrip ($script:Classes[$className][0])
            }
            $values = $reps.Values | Select-Object -Unique
            $values.Count | Should -Be $reps.Count -Because "awk should distinguish classes: $($reps | Out-String)"
        }

        It 'awk and PowerShell agree on whether each pair of inputs is equivalent' {
            foreach ($a in $script:Pairs)
            {
                foreach ($b in $script:Pairs)
                {
                    $pwshA = Get-DocsArticleBody $a.Input
                    $pwshB = Get-DocsArticleBody $b.Input
                    $awkA = Invoke-AwkStrip $a.Input
                    $awkB = Invoke-AwkStrip $b.Input

                    $pwshSame = $pwshA -eq $pwshB
                    $awkSame = $awkA -eq $awkB

                    $pwshSame | Should -Be $awkSame -Because (
                        "awk and pwsh disagree on equivalence for class='$($a.Class)' vs class='$($b.Class)'. " +
                        "pwsh: '$pwshA' vs '$pwshB' -> $pwshSame. awk: '$awkA' vs '$awkB' -> $awkSame."
                    )
                }
            }
        }
    }
}
