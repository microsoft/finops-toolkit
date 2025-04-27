import os
import re
import json
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from typing import Any, Callable, Set, Dict, List, Optional

# === KQL FUNCTION ===
import json
import datetime
import pandas as pd
from dotenv import load_dotenv
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table

# Load environment variables
load_dotenv()

ADX_CLUSTER_URL=os.getenv("ADX_CLUSTER_URL")
ADX_DATABASE=os.getenv("ADX_DATABASE")

def safe_serialize(data):
    def convert(obj):
        if isinstance(obj, pd.Timestamp):
            return obj.isoformat()
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        return str(obj)
    return json.dumps(data, default=convert)

from datetime import datetime
from typing import Optional

def query_adx_database(kql_query: str) -> str:
    """
    Run KQL queries on Azure Data Explorer (ADX).
    This tool helps analyze costs, trends, and anomalies using the Costs_v1_0 table.
    All queries must be read-only.
        <table>Costs_v1_0</table>
    <columns>
      AvailabilityZone, BilledCost, BillingAccountId, BillingAccountName, BillingAccountType, BillingCurrency,
      BillingPeriodEnd, BillingPeriodStart, ChargeCategory, ChargeClass, ChargeDescription, ChargeFrequency,
      ChargePeriodEnd, ChargePeriodStart, CommitmentDiscountCategory, CommitmentDiscountId, CommitmentDiscountName,
      CommitmentDiscountStatus, CommitmentDiscountType, ConsumedQuantity, ConsumedUnit, ContractedCost, ContractedUnitPrice,
      EffectiveCost, InvoiceIssuerName, ListCost, ListUnitPrice, PricingCategory, PricingQuantity, PricingUnit,
      ProviderName, PublisherName, RegionId, RegionName, ResourceId, ResourceName, ResourceType, ServiceCategory,
      ServiceName, SkuId, SkuPriceId, SubAccountId, SubAccountName, SubAccountType, Tags, x_AccountId, x_AccountName,
      x_AccountOwnerId, x_BilledCostInUsd, x_BilledUnitPrice, x_BillingAccountAgreement, x_BillingAccountId,
      x_BillingAccountName, x_BillingExchangeRate, x_BillingExchangeRateDate, x_BillingProfileId, x_BillingProfileName,
      x_ChargeId, x_ContractedCostInUsd, x_CostAllocationRuleName, x_CostCategories, x_CostCenter, x_Credits, x_CostType,
      x_CurrencyConversionRate, x_CustomerId, x_CustomerName, x_Discount, x_EffectiveCostInUsd, x_EffectiveUnitPrice,
      x_ExportTime, x_IngestionTime, x_InvoiceId, x_InvoiceIssuerId, x_InvoiceSectionId, x_InvoiceSectionName,
      x_ListCostInUsd, x_Location, x_Operation, x_PartnerCreditApplied, x_PartnerCreditRate, x_PricingBlockSize,
      x_PricingCurrency, x_PricingSubcategory, x_PricingUnitDescription, x_Project, x_PublisherCategory, x_PublisherId,
      x_ResellerId, x_ResellerName, x_ResourceGroupName, x_ResourceType, x_ServiceCode, x_ServiceId, x_ServicePeriodEnd,
      x_ServicePeriodStart, x_SkuDescription, x_SkuDetails, x_SkuIsCreditEligible, x_SkuMeterCategory, x_SkuMeterId,
      x_SkuMeterName, x_SkuMeterSubcategory, x_SkuOfferId, x_SkuOrderId, x_SkuOrderName, x_SkuPartNumber, x_SkuRegion,
      x_SkuServiceFamily, x_SkuTerm, x_SkuTier, x_SourceChanges, x_SourceName, x_SourceProvider, x_SourceType,
      x_SourceVersion, x_UsageType
    </columns>
    """
    today = datetime.utcnow().strftime("%Y-%m-%d")

    print("🔍 query_adx_database() was called")
    print(f"📆 Today (UTC): {today}")
    print(f"🔗 Cluster URL: {ADX_CLUSTER_URL}")
    print(f"📦 Database: {ADX_DATABASE}")
    print(f"📄 Original KQL: {kql_query}")

    # 🔁 Replace placeholder if used in the query
    if "{TODAY}" in kql_query:
        kql_query = kql_query.replace("{TODAY}", today)
        print(f"📄 KQL after token replacement: {kql_query}")
    else:
        print("⚠️ No token replacement needed.")

    try:
        kcsb = KustoConnectionStringBuilder.with_az_cli_authentication(ADX_CLUSTER_URL)
        client = KustoClient(kcsb)
        response = client.execute(ADX_DATABASE, kql_query)
        result_table = response.primary_results[0]
        df = dataframe_from_result_table(result_table)

        if df.empty:
            print("⚠️ DataFrame is empty.")
            return safe_serialize({
                "summary": "⚠️ Query executed but returned no rows.",
                "preview": []
            })

        billing_currency = df["BillingCurrency"].iloc[0] if "BillingCurrency" in df.columns else "USD"

        summary = ""
        matched_summary = False

        if "RegionName" in df.columns and "EffectiveCost" in df.columns:
            region = df["RegionName"].iloc[0]
            cost = df["EffectiveCost"].iloc[0]
            summary = (
                f"📊 Region '{region}' had the highest actual cost of "
                f"${cost:,.2f} {billing_currency} due to its resource usage."
            )
            matched_summary = True
        elif "ServiceName" in df.columns and "EffectiveCost" in df.columns:
            service = df["ServiceName"].iloc[0]
            cost = df["ActualCost"].iloc[0]
            summary = (
                f"💡 The top spending service is '{service}' with a cost of "
                f"${cost:,.2f} {billing_currency}."
            )
            matched_summary = True
        elif "ChargePeriodStart" in df.columns and "EffectiveCost" in df.columns:
            summary = (
                f"📈 Monthly cost trend over {len(df)} periods. "
                f"Latest cost: ${df['EffectiveCost'].iloc[-1]:,.2f}."
            )
            matched_summary = True
        elif "AnomalyScore" in df.columns:
            anomalies = df[df["AnomalyScore"].abs() > 2]
            summary = (
                f"🚨 Found {len(anomalies)} anomalies with high AnomalyScore (|score| > 2)."
            )
            matched_summary = True

        if not matched_summary:
            summary = f"✅ ADX query successful. Returned {len(df)} row(s)."

        preview = []
        for _, row in df.iterrows():
            row_dict = row.to_dict()
            row_dict["BillingCurrency"] = row_dict.get("BillingCurrency", billing_currency)
            preview.append(row_dict)

        print(f"✅ Returning {len(preview)} preview rows.")
        return safe_serialize({
            "summary": summary,
            "preview": preview[:50]
        })

    except Exception as e:
        print(f"❌ Exception in query_adx_database: {e}")
        return safe_serialize({
            "error": f"❌ Failed to query ADX: {str(e)}"
        })


# === AZURE SEARCH FUNCTION ===
def run_vector_search2(query_text: str) -> str:
    """Performs a semantic vector search against Azure AI Search."""
    endpoint = os.environ["AZURE_AI_SEARCH_SERVICE_ENDPOINT"]
    index_name = os.environ["AZURE_AI_SEARCH_INDEX_NAME"]
    key = os.environ["AZURE_SEARCH_ADMIN_KEY"]

    search_client = SearchClient(endpoint, index_name, AzureKeyCredential(key))

    vector_query = VectorizableTextQuery(
        text=query_text,
        k_nearest_neighbors=60,
        fields="contentVector,titleVector",
        exhaustive=True,
    )

    results = search_client.search(
        search_text=None,
        vector_queries=[vector_query],
        select=["title", "content"],
        top=3,
    )

    output_lines = ["## 🔍 Top Matching Documents\n"]
    source_links = []

    for i, result in enumerate(results, start=1):
        title = result.get("title", f"Document {i}")
        content = result.get("content", "[No content available]")
        snippet = content[:1500].strip().replace('\n', ' ')
        filename = re.sub(r'\W+', '-', title.lower()).strip('-') + ".md"
        score = getattr(result, "@search.score", None)

        output_lines.append(f"### {i}. 📄 **{title}**")
        if score:
            output_lines.append(f"**Relevance Score:** {score:.2f}")
        output_lines.append(f"{snippet}...\n---")

        source_links.append(f"- [{title}]({filename})")

    output_lines.append("\n**Sources:**")
    output_lines.extend(source_links)

    return "\n".join(output_lines)

# Statically defined user functions for fast reference
user_functions: Dict[str, Callable[..., Any]] = {
    "query_adx_database": query_adx_database,
    "run_vector_search2": run_vector_search2
}
