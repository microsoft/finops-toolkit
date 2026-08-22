#Requires -Version 5.1
# Proves a switch parameter resolves inside nested functions, which is how the
# multitool's pickers read -NonInteractive.

function Outer {
    [CmdletBinding()]
    param(
        [switch]$NonInteractive,
        [string[]]$Scans
    )

    function Inner-ReadsSwitch {
        if ($NonInteractive) { return 'NONINTERACTIVE' }
        return 'interactive'
    }

    function Inner-ReadsArray {
        if ($Scans -and $Scans.Count -gt 0) { return "scans=$($Scans -join '+')" }
        return 'no-scans'
    }

    [PSCustomObject]@{
        Switch = Inner-ReadsSwitch
        Array  = Inner-ReadsArray
    }
}

Write-Host '-- default --'
Outer | Format-List

Write-Host '-- with -NonInteractive and -Scans --'
Outer -NonInteractive -Scans 'A', 'B' | Format-List

$a = Outer
$b = Outer -NonInteractive -Scans 'A', 'B'
$ok = ($a.Switch -eq 'interactive') -and ($b.Switch -eq 'NONINTERACTIVE') -and
($a.Array -eq 'no-scans') -and ($b.Array -eq 'scans=A+B')
Write-Host ("RESULT: {0}" -f $(if ($ok) { 'PASS - nested functions see the parent parameters' } else { 'FAIL - parameters do NOT propagate' })) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
