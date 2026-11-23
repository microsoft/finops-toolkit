# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-SCANERRORHINT.PS1
# AZURE FINOPS MULTITOOL - Error hints for failed scans
###########################################################################
# Purpose: Explain a failed scan in terms that fit its cause. A request limit
#          or a timeout isn't fixed by a role assignment, so a permission hint
#          under every error sends readers to change access that is fine.
###########################################################################

# True when the message reads as an access problem. A failure that mentions a
# status code or service wording for denied access is treated as one.
function Test-ScanPermissionError {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()][AllowNull()][AllowEmptyString()][string]$Message
    )

    return [bool]($Message -match '(?i)\b40[13]\b|Forbidden|Unauthorized|AuthorizationFailed|does not have authorization|InsufficientPermissions|BillingAccountNotFound|access was denied|access denied')
}

# Returns the hint lines that fit the failure message. PermissionInfo carries the
# Role, Scope, and API the scan needs; without it no permission line is returned.
function Get-ScanErrorHint {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()][AllowNull()][AllowEmptyString()][string]$Message,
        [Parameter()][AllowNull()]$PermissionInfo
    )

    $isThrottled = $Message -match '(?i)\b429\b|too many requests|TooManyRequests|rate limit|limiting requests|throttl'
    $isTemporary = $Message -match '(?i)\b408\b|\b50[0-4]\b|timed out|timeout|temporary problem|didn''t respond|service unavailable'

    $lines = [System.Collections.Generic.List[string]]::new()
    if ($isThrottled) {
        $lines.Add("Cost Management limits how many requests a tenant can make, so this isn't a permission problem. Run the scan again later, or scan fewer subscriptions at a time.")
    }
    if ($isTemporary) {
        $lines.Add("The service or the network had a temporary problem, so this isn't a permission problem. Run the scan again.")
    }
    if ($PermissionInfo) {
        $needs = "$($PermissionInfo.Role) at $($PermissionInfo.Scope) scope ($($PermissionInfo.API))"
        if (Test-ScanPermissionError -Message $Message) { $lines.Add("Required: $needs") }
        elseif ($lines.Count -eq 0) { $lines.Add("If this is a permission problem, the scan needs $needs.") }
    }
    return $lines.ToArray()
}
