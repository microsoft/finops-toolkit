
function Remove-FinOpsCostExport
{
  [CmdletBinding(SupportsShouldProcess)]
  param
  (
      [Parameter(Mandatory = $true)]
      [string]
      $Name,

      [Parameter(Mandatory = $true)]
      [string]
      $Scope,

      [Parameter]
      [switch]
      $RemoveData,

      [Parameter()]
      [string]
      $ApiVersion = '2023-04-01-preview'
  )

  try {

  }
  catch {
    <#Do this if a terminating exception happens#>
  }
  finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
  }
}
