# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Sends Azure Resource Manager GET requests concurrently.

.DESCRIPTION
    Scans up to the concurrent subscriptions limit of subscriptions at a time on one HTTP client.
    Keeps up to the concurrent requests limit of requests in flight within each subscription, and follows nextLink pagination.
    Starts the next subscription when all requests of a subscription are complete.
    Returns one result per request as soon as all of its pages arrive.

.PARAMETER Requests
    Request hashtables. Each request must have a Subscription and a Path that starts with a forward slash.

.PARAMETER Client
    HTTP client with the ARM bearer token in its Authorization header.

.PARAMETER ConcurrentSubscriptions
    Maximum number of subscriptions scanned at a time.

.PARAMETER ConcurrentRequests
    Maximum number of requests in flight within each subscription.

.OUTPUTS
    Hashtable with Request, Data, and Error.
#>
function Get-ArmResponses {
    param (
        [System.Collections.Generic.List[object]]$Requests,
        [System.Net.Http.HttpClient]$Client,
        [int]$ConcurrentSubscriptions,
        [int]$ConcurrentRequests
    )

    # Queue the requests of each subscription in request order
    $scans = [ordered]@{}
    foreach ($request in $Requests) {
        $subscriptionId = $request.Subscription.subscriptionId
        if (-not $scans.Contains($subscriptionId)) {
            $scans[$subscriptionId] = @{ Pending = [System.Collections.Generic.Queue[object]]::new(); InFlight = 0 }
        }
        $scans[$subscriptionId].Pending.Enqueue($request)
    }
    $waiting = [System.Collections.Generic.Queue[object]]::new([object[]]@($scans.Values))
    $scanning = [System.Collections.Generic.List[object]]::new()

    $active = @{}
    while ($waiting.Count -or $scanning.Count) {
        while ($scanning.Count -lt $ConcurrentSubscriptions -and $waiting.Count) {
            $scanning.Add($waiting.Dequeue())
        }
        foreach ($scan in $scanning) {
            while ($scan.InFlight -lt $ConcurrentRequests -and $scan.Pending.Count) {
                $request = $scan.Pending.Dequeue()
                $uri = "https://management.azure.com$($request.Path)"
                $scan.InFlight++
                $active[$Client.GetStringAsync($uri)] = @{
                    Request = $request; Uri = $uri; Items = [System.Collections.Generic.List[object]]::new(); Scan = $scan
                }
            }
        }
        $task = [System.Threading.Tasks.Task]::WhenAny([System.Threading.Tasks.Task[]] @($active.Keys)).GetAwaiter().GetResult()
        $current = $active[$task]
        $active.Remove($task)
        $errorMessage = $null
        try {
            $page = ConvertFrom-Json -InputObject $task.GetAwaiter().GetResult() -ErrorAction Stop
            if ($page.PSObject.Properties.Name -contains 'value') {
                foreach ($item in $page.value) { $current.Items.Add($item) }
            }
            else { $current.Items.Add($page) }
            if ($page.nextLink) {
                $uri = [uri]$page.nextLink
                if ($uri.Scheme -ne 'https' -or $uri.Authority -ne 'management.azure.com') {
                    throw "Unexpected ARM pagination endpoint: $uri"
                }
                $current.Uri = $page.nextLink
                $active[$Client.GetStringAsync($current.Uri)] = $current
                continue
            }
        }
        catch {
            $errorMessage = "$($current.Uri): $($_.Exception.Message) $($_.ErrorDetails.Message)"
        }
        $data = @()
        if (-not $errorMessage) { $data = $current.Items.ToArray() }

        # Free the request slot, and finish the subscription scan when all of its requests are complete
        $current.Scan.InFlight--
        if (-not $current.Scan.InFlight -and -not $current.Scan.Pending.Count) { [void]$scanning.Remove($current.Scan) }
        @{ Request = $current.Request; Data = $data; Error = $errorMessage }
    }
}
