import pandas as pd
import sqlalchemy as sa
from sqlalchemy import create_engine
import struct
from itertools import chain, repeat
import pyodbc
import urllib
from azure.identity import DefaultAzureCredential
import traceback

def query_fabric_sql(query: str, debug: bool = False) -> str:
    """
    Function to query Azure SQL Database using SQLAlchemy and Azure AD authentication.
    Parameters:
        - query (str): The SQL query to execute.
        - debug (bool): If True, prints debug information.
    Returns:
        - str: The result of the query formatted as a Markdown table.

    Schema:
    <table>dbo.costdetails</table>
    <columns>
      BilledCost, BillingAccountId, BillingAccountName, BillingAccountType, BillingCurrency, BillingPeriodEnd, BillingPeriodStart,
      ChargeCategory, ChargeClass, ChargeDescription, ChargeFrequency, ChargePeriodEnd, ChargePeriodStart, CommitmentDiscountCategory,
      CommitmentDiscountId, CommitmentDiscountName, CommitmentDiscountStatus, CommitmentDiscountType, ConsumedQuantity, ConsumedUnit,
      ContractedCost, ContractedUnitPrice, EffectiveCost, InvoiceIssuerName, ListCost, ListUnitPrice, PricingCategory, PricingQuantity,
      PricingUnit, ProviderName, PublisherName, RegionId, RegionName, ResourceId, ResourceName, ResourceType, ServiceCategory,
      ServiceName, SkuId, SkuPriceId, SubAccountId, SubAccountName, SubAccountType, Tags, x_AccountId, x_AccountName, x_AccountOwnerId,
      x_BilledCostInUsd, x_BilledUnitPrice, x_BillingAccountId, x_BillingAccountName, x_BillingExchangeRate, x_BillingExchangeRateDate,
      x_BillingProfileId, x_BillingProfileName, x_ContractedCostInUsd, x_CostAllocationRuleName, x_CostCategories, x_CostCenter,
      x_CustomerId, x_CustomerName, x_EffectiveCostInUsd, x_EffectiveUnitPrice, x_InvoiceId, x_InvoiceIssuerId, x_InvoiceSectionId,
      x_InvoiceSectionName, x_ListCostInUsd, x_PartnerCreditApplied, x_PartnerCreditRate, x_PricingBlockSize, x_PricingCurrency,
      x_PricingSubcategory, x_PricingUnitDescription, x_PublisherCategory, x_PublisherId, x_ResellerId, x_ResellerName,
      x_ResourceGroupName, x_ResourceType, x_ServicePeriodEnd, x_ServicePeriodStart, x_SkuDescription, x_SkuDetails,
      x_SkuIsCreditEligible, x_SkuMeterCategory, x_SkuMeterId, x_SkuMeterName, x_SkuMeterSubcategory, x_SkuOfferId,
      x_SkuOrderId, x_SkuOrderName, x_SkuPartNumber, x_SkuRegion, x_SkuServiceFamily, x_SkuTerm, x_SkuTier
    </columns>
    
    """
    sql_endpoint = "ad5anxagdd6erbsnyr6et4atrq-3axrpjzvsvlu7mwhytyi37lyam.datawarehouse.fabric.microsoft.com"
    database = "FinOpsHub"
    driver = "ODBC Driver 18 for SQL Server"
    resource_url = "https://database.windows.net/.default"
    print("🔍 query_fabric_sql() was called")
    print(f"📄 Query: {query}")

    try:
        if debug:
            print("# Authenticating with Azure AD...")
        credential = DefaultAzureCredential()
        token_object = credential.get_token(resource_url)
        token_as_bytes = bytes(token_object.token, "UTF-8")
        encoded_bytes = bytes(chain.from_iterable(zip(token_as_bytes, repeat(0))))
        token_bytes = struct.pack("<i", len(encoded_bytes)) + encoded_bytes
        attrs_before = {1256: token_bytes}
    except Exception as auth_error:
        return (
            "## Authentication Failed\n"
            "**Error:**\n"
            f"{str(auth_error)}"
        )

    try:
        if debug:
            print("# Creating SQLAlchemy engine...")
        odbc_str = (
            f"Driver={{{driver}}};"
            f"Server={sql_endpoint},1433;"
            f"Database={database};"
            "Encrypt=Yes;"
            "TrustServerCertificate=No"
        )
        params = urllib.parse.quote_plus(odbc_str)
        engine = sa.create_engine(
            f"mssql+pyodbc:///?odbc_connect={params}",
            connect_args={"attrs_before": attrs_before},
        )
    except Exception as engine_error:
        return (
            "## Engine Creation Failed\n"
            "**Error:**\n"
            f"{str(engine_error)}"
        )

    try:
        if debug:
            print("# Connecting to database and executing query...")
        with engine.connect() as conn:
            df = pd.read_sql(query, conn)
            query_output = df.to_markdown(index=False) if not df.empty else "_No results found._"
            return (
                "## Query Executed Successfully\n\n"
                "### SQL Query:\n"
                f"{query.strip()}\n\n"
                "### Results:\n"
                f"{query_output}"
            )
    except Exception as query_error:
        return (
            "## Query Execution Failed\n\n"
            "### SQL Query:\n"
            f"{query.strip()}\n\n"
            "**Error:**\n"
            f"{str(query_error)}\n\n"
            "**Traceback:**\n"
            f"{traceback.format_exc()}"
        )



# # 🧪 Test locally
# if __name__ == "__main__":
#     query = """
#             SELECT TOP (100) [BilledCost],
#                         [BillingAccountId],
#                         [BillingAccountName],
#                         [BillingAccountType],
#                         [BillingCurrency],
#                         [BillingPeriodEnd],
#                         [BillingPeriodStart],
#                         [ChargeCategory],
#                         [ChargeClass],
#                         [ChargeDescription],
#                         [ChargeFrequency],
#                         [ChargePeriodEnd],
#                         [ChargePeriodStart],
#                         [CommitmentDiscountCategory],
#                         [CommitmentDiscountId],
#                         [CommitmentDiscountName],
#                         [CommitmentDiscountStatus],
#                         [CommitmentDiscountType],
#                         [ConsumedQuantity],
#                         [ConsumedUnit],
#                         [ContractedCost],
#                         [ContractedUnitPrice],
#                         [EffectiveCost],
#                         [InvoiceIssuerName],
#                         [ListCost],
#                         [ListUnitPrice],
#                         [PricingCategory],
#                         [PricingQuantity],
#                         [PricingUnit],
#                         [ProviderName],
#                         [PublisherName],
#                         [RegionId],
#                         [RegionName],
#                         [ResourceId],
#                         [ResourceName],
#                         [ResourceType],
#                         [ServiceCategory],
#                         [ServiceName],
#                         [SkuId],
#                         [SkuPriceId],
#                         [SubAccountId],
#                         [SubAccountName],
#                         [SubAccountType],
#                         [Tags],
#                         [x_AccountId],
#                         [x_AccountName],
#                         [x_AccountOwnerId],
#                         [x_BilledCostInUsd],
#                         [x_BilledUnitPrice],
#                         [x_BillingAccountId],
#                         [x_BillingAccountName],
#                         [x_BillingExchangeRate],
#                         [x_BillingExchangeRateDate],
#                         [x_BillingProfileId],
#                         [x_BillingProfileName],
#                         [x_ContractedCostInUsd],
#                         [x_CostAllocationRuleName],
#                         [x_CostCenter],
#                         [x_CustomerId],
#                         [x_CustomerName],
#                         [x_EffectiveCostInUsd],
#                         [x_EffectiveUnitPrice],
#                         [x_InvoiceId],
#                         [x_InvoiceIssuerId],
#                         [x_InvoiceSectionId],
#                         [x_InvoiceSectionName],
#                         [x_ListCostInUsd],
#                         [x_PartnerCreditApplied],
#                         [x_PartnerCreditRate],
#                         [x_PricingBlockSize],
#                         [x_PricingCurrency],
#                         [x_PricingSubcategory],
#                         [x_PricingUnitDescription],
#                         [x_PublisherCategory],
#                         [x_PublisherId],
#                         [x_ResellerId],
#                         [x_ResellerName],
#                         [x_ResourceGroupName],
#                         [x_ResourceType],
#                         [x_ServicePeriodEnd],
#                         [x_ServicePeriodStart],
#                         [x_SkuDescription],
#                         [x_SkuDetails],
#                         [x_SkuIsCreditEligible],
#                         [x_SkuMeterCategory],
#                         [x_SkuMeterId],
#                         [x_SkuMeterName],
#                         [x_SkuMeterSubcategory],
#                         [x_SkuOfferId],
#                         [x_SkuOrderId],
#                         [x_SkuOrderName],
#                         [x_SkuPartNumber],
#                         [x_SkuRegion],
#                         [x_SkuServiceFamily],
#                         [x_SkuTerm],
#                         [x_SkuTier]
#             FROM [FinOpsHub].[dbo].[costdetails]
#     """
# print(query_fabric_sql(query))