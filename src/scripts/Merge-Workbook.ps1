# Run from root of repo

$workbookPath = "./src/workbooks/optimization"
$workbookTemplate = "./src/workbooks/optimization/workbook_template.json"
$newTemplate = "$workbookPath/workbook.json"

## Create a new template
Copy-Item $workbookTemplate $newTemplate -Force

## Get contents of each sub-template
$computeGroupTemplate = Get-Content "$workbookPath/Compute/CostWorkbookCompute.workbook" -Raw
$storageGroupTemplate = Get-Content "$workbookPath/Storage/CostWorkbookStorage.workbook" -Raw
$networkingGroupTemplate = Get-Content "$workbookPath/Networking/CostWorkbookNetworking.workbook" -Raw
$ahubGroupTemplate = Get-Content "$workbookPath/AHUB/CostWorkbookAHUB.workbook" -Raw


$workbook = Get-Content $newTemplate

$computeGroupJson = $computeGroupTemplate | ConvertFrom-Json
$storageGroupJson = $storageGroupTemplate | ConvertFrom-Json
$networkingGroupJson = $networkingGroupTemplate | ConvertFrom-Json
$ahubGroupJson = $ahubGroupTemplate | ConvertFrom-Json

$computeObjects = ($computeGroupJson.items.content).items
$storageObjects = ($storageGroupJson.items.content).items
$networkingObjects = ($networkingGroupJson.items.content).items
$ahubObjects = $ahubGroupJson.items.content.items

$newWorbook = $workbook -replace "computeGroupPlaceholder", ($computeObjects[2..$computeObjects.Count] | ConvertTo-Json -Depth 20) `
-replace "storageGroupPlaceholder", ($storageObjects[2..$storageObjects.Count] | ConvertTo-Json -Depth 20) `
-replace "networkingGroupPlaceholder", ($networkingObjects[2..$networkingObjects.Count] | ConvertTo-Json -Depth 20) `
-replace "AHUBGroupPlaceholder", ($ahubObjects[2..$ahubObjects.Count] | ConvertTo-Json -Depth 20)

Set-Content $newTemplate -Value $newWorbook



