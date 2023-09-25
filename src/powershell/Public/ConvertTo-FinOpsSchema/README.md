# ConvertTo-FinOpsSchema

Converts Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema.

## Description

The ConvertTo-FinOpsSchema command returns an object that adheres to the FinOps Open Cost and Usage Specification (FOCUS) schema. It currently understands how to convert Cost Management cost data using the latest schemas as of September 2023. Older schemas may not be fully supported. Please review output and report any issues to https://aka.ms/ftk. You can pipe objects to ConvertTo-FinOpsSchema from an exported or downloaded CSV file using Import-Csv or ConvertFrom-Csv and pipe to Export-Csv to save as a CSV file.

## Parameters

### ActualCost

Specifies the actual cost data to be converted. Object must be a supported Microsoft Cost Management schema.

### AmortizedCost

Specifies the amortized cost data to be converted. Object must be a supported Microsoft Cost Management schema.

### Version

FOCUS schema version to convert data to. Allowed values: 0.5, 1.0-workingdraft, 1.0-preview. Default = 0.5.

## Examples

```powershell
ConvertTo-FinOpsSchema -ActualCost (Import-Csv my-actual-cost-details.csv) -AmortizedCost (Import-Csv my-amortized-cost-details.csv) | Export-Csv my-cost-details-in-focus.csv
```

## Notes

Version: 

Author: 

Date: 

## Usage

To use the `ConvertTo-FinOpsSchema` function, you can pass in actual cost data using the `-ActualCost` parameter. You can also pass in amortized cost data using the `-AmortizedCost` parameter, although this is optional. The function will return an object that adheres to the FinOps Open Cost and Usage Specification (FOCUS) schema.

You can pipe objects to `ConvertTo-FinOpsSchema` from an exported or downloaded CSV file using `Import-Csv` or `ConvertFrom-Csv` and pipe to `Export-Csv` to save as a CSV file.


### To use the function, you can call it like this:

```powershell
$actualCostData = Import-Csv "my-actual-cost-details.csv"
$transformedData = ConvertTo-FinOpsSchema -ActualCost $actualCostData
$transformedData | Export-Csv "my-cost-details-in-focus.csv" -NoTypeInformation
```

This will import the actual cost data from the `my-actual-cost-details.csv` file, transform it using the `ConvertTo-FinOpsSchema` function, and export the transformed data to the `my-cost-details-in-focus.csv` file.



### Parameters

| Parameter Name | Mandatory | Data Type | Default Value | Valid Values |
| --- | --- | --- | --- | --- |
| ActualCost | True | Object | N/A | N/A |
| AmortizedCost | False | Object | N/A | N/A |
| Version | False | String | 0.5 | 0.5, 1.0-workingdraft, 1.0-preview |



## Testing

You can test the `ConvertTo-FinOpsSchema` function using actual CSV input data. To do this, you can call the function like this:

```powershell
if ((Test-Path $actualCostCsvPath) -and (Test-Path $amortizedCostCsvPath)) {
    $actualCostData = Import-Csv $actualCostCsvPath
    $amortizedCostData = Import-Csv $amortizedCostCsvPath
    
    Write-Host "Actual Cost Data Count: $($actualCostData.Count)"
    Write-Host "Amortized Cost Data Count: $($amortizedCostData.Count)"
    
    $transformedData = ConvertTo-FinOpsSchema -ActualCost $actualCostData -AmortizedCost $amortizedCostData
    Write-Host "Transformed Data Count: $($transformedData.Count)"
    
    $transformedData | Export-Csv "TransformedCombinedData.csv" -NoTypeInformation
} else {
    Write-Host "Error: Either $actualCostCsvPath or $amortizedCostCsvPath does not exist."
}

```

This will import the actual cost data from the `my-actual-cost-details.csv` and the `my-amortized-cost-details.csv` file, transform it using the `ConvertTo-FinOpsSchema` function, and export the transformed data to the `my-cost-details-in-focus.csv` file.

## Unit Tests

The `ConvertTo-FinOpsSchema` function includes a set of unit tests using the Pester framework. These tests cover scenarios such as throwing an error if ActualCost data is empty or null, throwing an error if the cost details schema is not supported, and modifying column names.

To run the tests, you need to have Pester installed on your machine. You can install Pester by running the following command in PowerShell:

```powershell
Install-Module -Name Pester -Force
```

Once you have Pester installed, you can run the tests by executing the script in PowerShell. The tests will run automatically and output the results to the console.

To run the tests, you can either execute the script directly in PowerShell or use the Pester command-line interface. For example, to run the tests using the Pester command-line interface, you can navigate to the directory containing the script and run the following command:

```powershell
Invoke-Pester .\ConvertTo-FinOpsSchema.Tests.ps1 -Output Detailed
```

This will run all the tests in the `ConvertTo-FinOpsSchema.Tests.ps1` script and output the results to the console.


```powershell
Describe "ConvertTo-FinOpsSchema" {
    BeforeAll {
        . $PSCommandPath.Replace('.ConvertTo-FinOpsSchema.ps1', '.ps1')
        # Set the script scope variables
        $script:ActualCost = @(
            [PSCustomObject]@{
                BillingAccountId = "123"
                BillingAccountName = "Test Account"
                BillingPeriodStartDate = "2021-01-01"
                BillingPeriodEndDate = "2021-01-31"
                BillingProfileId = "123"
                BillingProfileName = "Test Profile"
                AccountOwnerId = "123"
                AccountName = "Test Account"
            }
        )

        $script:AmortizedCost = @(
            [PSCustomObject]@{
                BillingAccountId = "456"
                BillingAccountName = "Test Account"     
                BillingPeriodStartDate = "2021-01-01"
                BillingPeriodEndDate = "2021-01-31"
                BillingProfileId = "456"
                BillingProfileName = "Test Profile"
                AccountOwnerId = "456"
                AccountName = "Test Account"   
            }
        )
    }
    It "Should throw an error if Combined Cost data is empty or null" {
        { ConvertTo-FinOpsSchema -ActualCost @() -AmortizedCost @() } | Should -Throw -ExpectedMessage "Combined Cost data is empty or null."
    }

    It "Should throw an error if Cost details schema not supported" {
        $invalidData = @(
            [PSCustomObject]@{
                InvalidColumn = "123"
            }
        )
        # Throw an error if actual cost and amortized cost contain invalid data
        # { 
        #     ConvertTo-FinOpsSchema -ActualCost $invalidData -AmortizedCost $invalidData
        # }
        { ConvertTo-FinOpsSchema -ActualCost $invalidData -AmortizedCost $invalidData } | Should -Throw -ExpectedMessage "Cost details schema not supported."
    }
    Context "Column name transformations" {

        It "Should prepend 'ftk_' to column names" {
            $result = ConvertTo-FinOpsSchema -ActualCost $script:ActualCost -AmortizedCost $script:AmortizedCost
            $result[0].PSObject.Properties.Name -contains "ftk_BillingAccountId" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_BillingAccountName" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_BillingPeriodStartDate" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_BillingPeriodEndDate" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_BillingProfileId" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_BillingProfileName" | Should -Be $true
            $result[0].PSObject.Properties.Name -contains "ftk_AccountOwnerId" | Should -Be $true
            # Amortized Cost data
            $result[1].PSObject.Properties.Name -contains "ftk_BillingAccountId" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_BillingAccountName" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_BillingPeriodStartDate" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_BillingPeriodEndDate" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_BillingProfileId" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_BillingProfileName" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_AccountOwnerId" | Should -Be $true
            $result[1].PSObject.Properties.Name -contains "ftk_AccountName" | Should -Be $true
        }
    }



    # Additional test cases can be added as needed
}
```

You can also add more tests for other transformations as needed. To do this, you can add a new `It` block to the `Describe` block and write a test that covers the new transformation.

```powershell
It "should transform the date format" {
    $testData = @(
        [PSCustomObject]@{billingAccountId = "123"; ChargeType = "Purchase"; PricingModel = "Reservation"; SomeOtherField = "TestData"; Date = "2022-01-01"}
        [PSCustomObject]@{billingAccountId = "124"; ChargeType = "Other"; PricingModel = "OtherModel"; SomeOtherField = "TestData2"; Date = "2022-01-02"}
    )

    $result = ConvertTo-FinOpsSchema -ActualCost $testData
    $result[0].Date | Should Be "01/01/2022"
    $result[1].Date | Should Be "01/02/2022"
}
This test will transform the date format from "yyyy-MM-dd" to "MM/dd/yyyy".
```
You can save the output file in the same folder path as the Pester test file by using a relative path for the `-OutputFile` parameter. 

Here's an example of how you can modify the `Invoke-Pester` command to output the test results to a file in the same folder as the Pester test file:

```powershell
Invoke-Pester -Path .\ConvertTo-FinOpsSchema.Tests.ps1 -OutputFile .\TestResults.xml
```

When you run this command, Pester will execute the tests and save the results to a file named `TestResults.xml` in the same folder as the Pester test file.
## Troubleshooting

If you encounter any issues with the `ConvertTo-FinOpsSchema` function, please review the output and report any issues to https://aka.ms/ftk.