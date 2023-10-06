# FinOps toolkit PowerShell module

The **FinOpsToolkit** PowerShell module is dynamically generated. To test it locally, run the build script and import the local module:

```powershell
Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
<root>/.build/.start.ps1 -Task Build.PsModule
Import-Module <root>/release/FinOpsToolkit/FinOpsToolkit.psm1
```

<br>
