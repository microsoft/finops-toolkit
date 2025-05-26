# query_adx_strict.py

import os
import json
import datetime
import pandas as pd
from dotenv import load_dotenv
from typing import List, Dict, Union
from pydantic import BaseModel, Field
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table
from openai import AzureOpenAI

# ─── Load .env ──────────────────────────────────────────────────────────────────
load_dotenv()
ADX_CLUSTER_URL = os.getenv("ADX_CLUSTER_URL")
ADX_DATABASE = os.getenv("ADX_DATABASE")
OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY")
OPENAI_MODEL = os.getenv("AZURE_OPENAI_MODEL_NAME", "gpt-4.1-nano")


# ─── Pydantic schema ────────────────────────────────────────────────────────────
class ADXPreviewRow(BaseModel):
    BillingCurrency: str
    row: Dict[str, Union[str, float, int]] = Field(
        ..., description="Dynamic columns from the ADX query result"
    )


class ADXQueryResult(BaseModel):
    summary: str
    preview: List[ADXPreviewRow]


# ─── Azure OpenAI client ────────────────────────────────────────────────────────
client = AzureOpenAI(
    api_key=OPENAI_KEY,
    azure_endpoint=OPENAI_ENDPOINT,
    api_version="2024-12-01-preview",
)


# ─── Kusto client helper ───────────────────────────────────────────────────────
def create_kusto_client(cluster_url: str) -> KustoClient:
    """
    Try AZ CLI auth first, then fall back to Managed Identity.
    """
    try:
        print("🔵 Trying Azure CLI authentication...")
        kcsb = KustoConnectionStringBuilder.with_az_cli_authentication(cluster_url)
        kc = KustoClient(kcsb)
        kc.execute_mgmt("NetDefaultDB", ".show version")
        print("✅ Azure CLI authentication successful.")
        return kc

    except Exception as cli_exc:
        print(f"⚠️ Azure CLI auth failed: {cli_exc}")
        print("🟣 Falling back to Managed Identity...")
        try:
            kcsb = KustoConnectionStringBuilder.with_aad_managed_service_identity_authentication(
                cluster_url
            )
            kc = KustoClient(kcsb)
            kc.execute_mgmt("NetDefaultDB", ".show version")
            print("✅ Managed Identity authentication successful.")
            return kc
        except Exception as mi_exc:
            print(f"❌ Managed Identity auth failed: {mi_exc}")
            raise


# ─── KQL fix suggester ──────────────────────────────────────────────────────────
def suggest_kql_fix(original_query: str, error_msg: str) -> str:
    """
    Ask Finley (via the Azure OpenAI client) to propose a corrected KQL query.
    Returns just the fixed KQL (no markdown).
    """
    system = {
        "role": "system",
        "content": (
            """
            "You are Finley, an expert in Azure Data Explorer (KQL) and Kusto query language.\n"
            "You are very good at fixing KQL queries.\n"
            "<table>Costs_v1_0</table>
            "<columns>
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
            </columns>"
            "When given a failing query and its error, propose a single corrected query."""
        ),
    }
    user = {
        "role": "user",
        "content": (
            f"The following KQL failed with this error:\n\n"
            f"{error_msg}\n\n"
            f"Original query:\n```kusto\n{original_query}\n```\n\n"
            "Return only the corrected KQL (no explanations)."
        ),
    }

    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        temperature=0.3,
        messages=[system, user],
    )
    fixed = resp.choices[0].message.content.strip()
    # strip code fences if present
    return fixed.strip("```").strip()


# ─── LLM summarizer ─────────────────────────────────────────────────────────────
def call_llm_strict_summary_dynamic(df: pd.DataFrame) -> dict:
    """
    Send the rows as JSON to Azure OpenAI with a strict schema.
    """
    # data_preview = df.head().fillna("").to_dict(orient="records") //limits to 5 rows
    data_preview = df.fillna("").to_dict(orient="records")

    for row in data_preview:
        for k, v in row.items():
            if isinstance(v, (pd.Timestamp, datetime.datetime, datetime.date)):
                row[k] = v.isoformat()
    print(f"🔍 Sending {len(data_preview)} rows to LLM for summarization...")

    prompt = f"""
You are Finley, the witty but professional FinOps assistant.

Given this Azure cost data, respond **only** with a single valid JSON object matching this schema:

  {{
    "summary": "A human-readable business insight",
    "preview": [
      {{
        "BillingCurrency": "USD",
        "row": {{ /* all other columns */ }}
      }}
    ]
  }}

Here is the data, already JSON-safe:
{json.dumps(data_preview, indent=2)}
"""

    # Build JSON Schema with additionalProperties=false
    schema = ADXQueryResult.model_json_schema()
    schema["additionalProperties"] = False

    response_format = {
        "type": "json_schema",
        "json_schema": {
            "name": "ADXQueryResult",
            "description": "Structured output for Finley ADX queries",
            "schema": schema,
        },
    }

    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        temperature=0.2,
        top_p=0.3,
        response_format=response_format,
        messages=[
            {
                "role": "system",
                "content": "You must respond with valid JSON matching the schema above. Always use markdown as your output.",
            },
            {"role": "user", "content": prompt},
        ],
    )

    # Normalize & validate
    content = resp.choices[0].message.content
    try:
        parsed = content if isinstance(content, dict) else json.loads(content)
        validated = ADXQueryResult(**parsed)
        return validated.dict()
    except Exception:
        return {"summary": content.strip(), "preview": []}


# ─── Main tool function ────────────────────────────────────────────────────────
def query_adx_database(kql_query: str) -> dict:
    """
    Execute the KQL in ADX, log details, then delegate to the LLM for formatting.
    If the ADX call fails, ask Finley to fix the KQL and include that suggestion.
    """
    today = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    print("🔍 query_adx_database() was called")
    print(f"📆 Today (UTC): {today}")
    print(f"🔗 Cluster URL: {ADX_CLUSTER_URL}")
    print(f"📦 Database: {ADX_DATABASE}")
    print(f"📄 Original KQL: {kql_query}")

    if "{TODAY}" in kql_query:
        kql_query = kql_query.replace("{TODAY}", today)
        print(f"📄 KQL after token replacement: {kql_query}")
    else:
        print("⚠️ No token replacement needed.")

    try:
        kusto = create_kusto_client(ADX_CLUSTER_URL)
        res = kusto.execute(ADX_DATABASE, kql_query)
        df = dataframe_from_result_table(res.primary_results[0])
        print(f"✅ Retrieved {len(df)} row(s) from ADX.")

        if df.empty:
            print("⚠️ DataFrame is empty.")
            return {"summary": "⚠️ Query executed but returned no rows.", "preview": []}

        # Standardize column names
        if "BillingCurrency" not in df.columns:
            df["BillingCurrency"] = "USD"
            print("ℹ️ Added missing BillingCurrency=USD to all rows.")
        # if "EffectiveCost" in df.columns:
        #     df = df.rename(columns={"EffectiveCost": "TotalCost"})
        #     print("ℹ️ Renamed column EffectiveCost→TotalCost.")

        # Delegate to LLM for summary only
        llm_output = call_llm_strict_summary_dynamic(
            df.head()
        )  # or just `df` if you want LLM to see all too
        summary = llm_output.get("summary", "")

        # Prepare full preview for frontend
        full_preview = df.fillna("").to_dict(orient="records")
        for row in full_preview:
            for k, v in row.items():
                if isinstance(v, (pd.Timestamp, datetime.datetime, datetime.date)):
                    row[k] = v.isoformat()

        return {
            "summary": summary,
            "preview": [
                {"BillingCurrency": row.get("BillingCurrency", "USD"), "row": row}
                for row in full_preview
            ],
        }

    except Exception as e:
        err = str(e)
        print(f"❌ Exception in query_adx_database: {err}")

        # Ask Finley to propose a corrected KQL
        suggested = None
        try:
            suggested = suggest_kql_fix(kql_query, err)
            print(f"💡 Suggested KQL fix: {suggested}")
        except Exception as fix_err:
            print(f"❌ Failed to get suggestion from LLM: {fix_err}")

        # Return error + optional suggestion
        out = {"summary": f"❌ ADX query failed: {err}", "preview": []}
        if suggested:
            out["suggestedQuery"] = suggested
        return out


# ─── Quick test ────────────────────────────────────────────────────────────────
# if __name__ == "__main__":
# #     test_kql = "Costs_v1_0 | summarize sum(EffectiveCost) by ServiceName"
#     test_kql = "let costs = Costs_v1_0 | where ChargePeriodStart >= startofmonth(ago(1d)); let all = costs | summarize sum(EffectiveCost) by ServiceName; all | order by sum_EffectiveCost desc | limit 5"  
#     print(json.dumps(query_adx_database(test_kql), indent=2))
    