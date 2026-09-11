###########################################################################
# GET-JITTEREDDELAY.PS1
# RETRY BACKOFF JITTER
###########################################################################
# Purpose: Spread retry wake-ups so concurrent scans stop retrying in lockstep
# Author: Zac Larsen
# Date: Created for FinOps Multitool
#
# Description:
# Pure exponential backoff is deterministic, so several scans that are
# throttled by the same Azure endpoint at the same moment will all sleep for
# the same interval and retry together, re-triggering the throttle. This
# helper adds randomness to break that synchronization:
# 1. Computed backoff uses equal jitter - half the delay is fixed, half is
#    random - which keeps a sensible floor while decorrelating callers.
# 2. A server-supplied Retry-After is treated as a hard floor and only ever
#    extended, never shortened, so the service's instruction is respected.
#
# -- Parameters -------------------------------------------------------------
# BaseSeconds        Computed backoff to jitter, in seconds
# RetryAfterSeconds  Server-supplied Retry-After floor, in seconds
#
# Usage: Get-JitteredDelay -BaseSeconds 8
###########################################################################

function Get-JitteredDelay {
    [CmdletBinding(DefaultParameterSetName = 'Computed')]
    [OutputType([double])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Computed')]
        [double]$BaseSeconds,

        [Parameter(Mandatory, ParameterSetName = 'RetryAfter')]
        [double]$RetryAfterSeconds
    )

    if ($PSCmdlet.ParameterSetName -eq 'RetryAfter') {
        # Never sleep less than the service asked for; add up to 1s of spread.
        if ($RetryAfterSeconds -lt 0) { $RetryAfterSeconds = 0 }
        return $RetryAfterSeconds + (Get-Random -Minimum 0.0 -Maximum 1.0)
    }

    if ($BaseSeconds -le 0) { return 0.0 }

    # Equal jitter: floor at half the backoff, randomize the other half.
    $half = $BaseSeconds / 2
    return $half + (Get-Random -Minimum 0.0 -Maximum $half)
}
