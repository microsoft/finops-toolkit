# Add Pester tests
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Output.Verbosity = 'Detailed'
# . source the script
. ..\Public\ConvertTo-FinOpsSchema\ConvertTo-FinOpsSchema.ps1



# Check the current working directory
# Get-Location

# Set the working directory if needed
# Set-Location ".\"


#### Use Execution policy only if needed (e.g. if the script is not signed, etc.) ###
# Check the execution policy
# Get-ExecutionPolicy
# Set the execution policy to RemoteSigned if needed
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force


# Install/Update Pester if needed
# Check Pester version
Get-Module Pester -ListAvailable
# Install/Update Pester
Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser

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
