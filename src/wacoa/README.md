# Azure Cost Recommendations Script (ACORL)

This PowerShell script solution automates the generation of cost optimization recommendations for your Azure resources. It combines Azure Resource Graph (ARG) queries, YAML-based definitions, and optional Well-Architected Framework assessment data to provide a comprehensive view of potential savings.

## Table of Contents

- [Azure Cost Recommendations Script (ACORL)](#azure-cost-recommendations-script-acorl)
  - [Table of Contents](#table-of-contents)
  - [**Key Features**](#key-features)
  - [**Workflow Overview**](#workflow-overview)
  - [**System Requirements**](#system-requirements)
  - [**Collecting Cost Recommendations**](#collecting-cost-recommendations)
    - [**Usage**](#usage)
  - [**Supporting Files**](#supporting-files)
    - [`settings.json` (Auto-generated/Customizable)](#settingsjson-auto-generatedcustomizable)
    - [`azure-resources/` (Auto-downloaded)](#azure-resources-auto-downloaded)
    - [Scope Definition JSON File (Optional)](#scope-definition-json-file-optional)
  - [**Generating a PowerPoint Presentation**](#generating-a-powerpoint-presentation)
    - [**Usage**](#usage-1)

---

## **Key Features**

*   ✅ **Automated KQL Queries:** Executes predefined Kusto Query Language (KQL) queries against Azure Resource Graph to pinpoint cost optimization opportunities.
*   🔍 **YAML-based Recommendations:**
    *   Integrates "manual" validation checks by processing YAML files, validating them against resource types present in your scope.
    *   Includes "custom cost" YAML recommendations directly without prior ARG validation.
*   🔍 **Well-Architected Framework Integration:** Incorporates results from a Well-Architected Cost Optimization assessment CSV file for a holistic view.
*   ✅ **Comprehensive Excel Export:** Consolidates all findings into a structured Excel file with distinct sheets for KQL-based recommendations, YAML-based recommendations, and Well-Architected assessment data.
*   ✅ **Flexible Scope Selection:** Supports analysis across your entire Azure environment, specific subscriptions, or resource groups defined in a JSON file. Caches the last used scope for convenience.
*   ⚙️ **Self-Management & Updates:**
    *   Automatically downloads missing prerequisite scripts.
    *   Checks for newer versions of the main script and notifies the user.
    *   Can download and apply updates to itself and prerequisite scripts.
*   ⚙️ **Configurable Settings:** Utilizes a `settings.json` file for repository URLs, and local paths.
*   📝 **Detailed Logging:** Generates a timestamped log file for troubleshooting and audit purposes.

---

## **Workflow Overview**

1.  **Initialization & Setup:**
    *   The script verifies PowerShell version (7+ required).
    *   Loads settings from `settings.json` (creates it with defaults if not found).
    *   Checks for script updates and handles missing prerequisite scripts.
    *   Installs required PowerShell modules if missing: `Az.Accounts`, `Az.ResourceGraph`, `ImportExcel`, `powershell-yaml`.
    *   Establishes an Azure connection (prompts for login if needed).
    *   Downloads and extracts recommendation definition files (KQL, YAML) from a configured GitHub repository to a local `Temp/azure-resources` folder if not already present.

2.  **User Prompts & Configuration:**
    *   **Well-Architected Assessment (Optional):** Asks if you want to include results from a Well-Architected Cost Optimization assessment CSV file.
    *   **Scope Definition:** Prompts for the analysis scope:
        *   Reuse cached scope from the previous run.
        *   Entire Azure environment accessible.
        *   Load scope from a user-selected JSON file (defining specific subscriptions/resource groups).
    *   **Manual Checks (Optional):** Asks if you want to run "manual checks," which involves processing YAML-based recommendations.

3.  **Recommendation Processing:**
    *   **YAML Recommendations (if manual checks enabled):**
        *   Processes YAML files from a `CustomCost` subfolder directly.
        *   For other YAML files, queries ARG to find relevant resource types within the defined scope and processes only matching YAMLs. Results are added to the Excel report.
    *   **KQL-based Recommendations:**
        *   Executes KQL queries (from downloaded `.kql` files) against Azure Resource Graph, applying scope filters.
        *   Collects identified resources.

4.  **Report Generation & Output:**
    *   Summarizes KQL-based recommendations by priority and resource type to the console.
    *   Exports all collected recommendations (KQL, YAML, and optional Well-Architected data) into a timestamped Excel file (`ACORL-File-YYYY-MM-DD-HH-mm.xlsx`).
    *   Creates a detailed, timestamped log file (`ACORL-Log-YYYY-MM-DD-HH-mm.log`).
    *   Displays paths to the generated Excel report and log file.

---

## **System Requirements**

*   **PowerShell 7+:** Ensure PowerShell version 7 or later is installed.
*   **Azure PowerShell Modules:** The script attempts to auto-install these if missing:
    *   `Az.Accounts` (for Azure authentication)
    *   `Az.ResourceGraph` (for querying Azure resources)
    *   `ImportExcel` (for generating Excel reports)
    *   `powershell-yaml` (for parsing YAML files)
*   **Azure Permissions:** The account running the script needs **Reader** access (or equivalent) at the intended scope of analysis (Management Group, Subscription, or Resource Group level).
*   **Operating System:** Windows (due to `System.Windows.Forms` used for file dialogs).


---

## **Collecting Cost Recommendations**

### **Usage**

1.  **Download the Main Script:**

    ```powershell
    Invoke-WebRequest -Uri https://aka.ms/acorl/tools/costcollector -OutFile collectCostRecommendations.ps1
    ```
    *   The `CostRecommendations-Prerequisites.ps1` script will be automatically downloaded by `CostRecommendations.ps1` if it's not found in the same directory.

2.  **Prepare for First Run:**
    *   On the first run, if `settings.json` is not present, it will be created with default values. You can review and customize this file if needed (e.g., if using a forked repository for updates or resources).
    *   The script will also download and extract KQL/YAML definition files into a `Temp/azure-resources` subfolder.

3.  **Execute the Script:**
    *   Open a PowerShell 7+ console.
    *   Navigate to the directory where you saved `CostRecommendations.ps1`.
    *   Run the script:
        ```powershell
        .\collectCostRecommendations.ps1
        ```
    *   You can also use the `-Verbose` switch for more detailed console output:
        ```powershell
        .\collectCostRecommendations.ps1-Verbose
        ```

4.  **Follow the Interactive Prompts:**
    *   **Azure Login:** If not already connected, an Azure login window will appear.
    *   **Script Version Check:** If a newer version of the script is found (based on `settings.json` configuration), you'll be notified and asked if you wish to continue with the current version or stop to download the latest.
    *   **Well-Architected Assessment:** Choose "Yes" or "Y" to include a Well-Architected assessment CSV, then select the file using the dialog.
    *   **Scope Selection:**
        *   If a cached scope exists, you'll be asked to reuse it.
        *   Otherwise, choose:
            *   `1. Entire environment (no filters).`
            *   `2. Load scope(s) from JSON file.` (A file dialog will appear to select the JSON file. See [Scope Definition JSON File](#scope-definition-json-file-optional) below).
    *   **Manual Checks:** Choose "Yes" or "Y" to process YAML-based recommendations.
    *   **Script Self-Update (if triggered, e.g., missing prerequisites):** If the script updates itself, it may ask if you want to restart with the new version.

5.  **Review the Output:**
    *   An Excel file named `ACORL-File-YYYY-MM-DD-HH-mm.xlsx` will be generated in the script's directory.
    *   A log file named `ACORL-Log-YYYY-MM-DD-HH-mm.log` will also be created.
    *   Review the console for a summary of recommendations and paths to the output files.

---

## **Supporting Files**

### `settings.json` (Auto-generated/Customizable)
*   **Location:** Same directory as `collectCostRecommendations.ps1`.
*   **Purpose:** Stores configuration for script version, repository URLs (for updates and resource downloads), and local paths.

### `azure-resources/` (Auto-downloaded)
*   **Location:** `Temp/azure-resources/` within the script's working directory (path configurable in `settings.json`).
*   **Content:** Contains `.kql` and `.yaml` files that define the cost optimization checks.
    *   YAML files in a `CustomCost` subfolder are processed directly.
    *   Other YAMLs are validated against resource types in your scope.

### Scope Definition JSON File (Optional)
*   **Purpose:** Used if you select "Load scope(s) from JSON file" during the scope selection prompt.
*   **Format:** A JSON file with a top-level `scopes` array. Each item in the array is an object with a `scope` property, whose value is the Azure Resource ID of a subscription or resource group.
    **Example `myScope.json`:**
    ```json
    {
        "scopes": [
            {
                "scope": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            },
            {
                "scope": "/subscriptions/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy/resourceGroups/MyResourceGroup1"
            }
        ]
    }
    ```


## **Generating a PowerPoint Presentation**

* `generateCostPPT.ps1`: This script transforms the Excel output from `collectCostRecommendations.ps1` into a PowerPoint presentation, designed for presentation in close-out meetings.

⚠️ Currently generateCostPPT.ps1 processes both "Manual Recommendations" and "Recommendations" tabs and skips the "Well-Architected Assessment" tab

The PowerPoint template is available in the IPKit at https://aka.ms/ipkit-wacoa (internal only). Please download the .pptx file located at:
V5\Delivery Artifacts\Well-Architected Cost Optimization Assessment Executive Summary.pptx

### **Usage**

* **`-InputPath` (Mandatory):** The full path to the Excel file generated by `collectCostRecommendations.ps1`.
* **`-PowerPointPath` (Mandatory):** The path to the PowerPoint presentation template that will be populated with the data.
* **`-OutputPath` (Optional):** The desired path for the generated PowerPoint presentation. If omitted, a timestamped file will be created in the same directory as the input PowerPoint file.

1.  **Download the Script:**
    ```powershell
    Invoke-WebRequest -Uri https://aka.ms/acorl/tools/generatecostppt -OutFile generateCostPPT.ps1
    ```

2.  **Execute the Script:**
    ```powershell
    .\generateCostPPT.ps1 -InputPath "C:\Path\To\Your\Recommendations.xlsx" -PowerPointPath "C:\Path\To\Your\Well-Architected Cost Optimization Assessment Executive Summary.pptx" -OutputPath "C:\Path\To\Your\UpdatedPresentation.pptx"
    ```

    * Replace `"C:\Path\To\Your\Recommendations.xlsx"` with the actual path to your Excel file.
    * Replace `"C:\Path\To\Your\Well-Architected Cost Optimization Assessment Executive Summary.pptx"` with the path to your PowerPoint template.
    * Replace `"C:\Path\To\Your\UpdatedPresentation.pptx"` with the desired output path (optional).

    **Example (without specifying OutputPath):**

    ```powershell
    .\generateCostPPT.ps1 -InputPath "C:\Data\AzureRecommendations.xlsx" -PowerPointPath "C:\Presentations\OriginalPresentation.pptx"
    ```
    ## **Troubleshooting**

### **Error: Exception calling "Load" with "1" argument(s): "The file is not a valid Package file. If the file is encrypted, please supply the password in the constructor."**

If you encounter the error:

Follow these steps:

1. **Check if the file is encrypted:**
   - This error occurs when the PowerPoint (`.pptx`) or Excel (`.xlsx`) file is encrypted or marked as confidential.
   
2. **Change the file sensitivity:**
   - If the file is marked as "Confidential", change its sensitivity to "General".
   - For PowerPoint (`.pptx`) or Excel (`.xlsx`) files, follow these steps:
     1. Open the file in Microsoft Office.
     2. Go to "File" -> "Info".
     3. Under "Properties", change the file's sensitivity to "General".
   
3. **Recreate the file:**
   - If the error persists, recreate the file, ensuring it is not configured with security restrictions or encryption.
