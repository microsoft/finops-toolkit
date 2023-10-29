# FinOps toolkit PowerShell module

The **FinOpsToolkit** PowerShell module is dynamically generated. To test it locally, you can run the build script or use the `src/scripts/Test-PowerShell.ps1` script. See [Test-PowerShell](../scripts/README.md#-test-powershell) for details.

When creating tests, initialize the module with the following line at the top of your test file:

```powershell
& "$PSScriptRoot/../Initialize-Tests.ps1"
```

<br>
