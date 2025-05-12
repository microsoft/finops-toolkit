import os
import re
import json
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from typing import Any, Callable, Set, Dict, List, Optional
from azure.identity import ManagedIdentityCredential
from dotenv import load_dotenv
from typing import Callable, Dict, Any
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table
import json
import datetime
import pandas as pd


load_dotenv()

ADX_CLUSTER_URL = os.getenv("ADX_CLUSTER_URL")
ADX_DATABASE = os.getenv("ADX_DATABASE")


def safe_serialize(data):
    def convert(obj):
        if isinstance(obj, pd.Timestamp):
            return obj.isoformat()
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        return str(obj)

    return json.dumps(data, default=convert)


# === KQL FUNCTION ===
def create_kusto_client(cluster_url: str) -> KustoClient:
    """
    Create a KustoClient using Azure CLI if available, otherwise fallback to Managed Identity.
    """
    try:
        print("🔵 Trying Azure CLI authentication...")
        kcsb = KustoConnectionStringBuilder.with_az_cli_authentication(cluster_url)
        client = KustoClient(kcsb)
        client.execute_mgmt("NetDefaultDB", ".show version")
        print("✅ Azure CLI authentication successful.")
        return client

    except Exception as e:
        print(f"⚠️ Azure CLI auth failed: {e}")
        print("🟣 Falling back to Managed Identity...")
        try:
            kcsb = KustoConnectionStringBuilder.with_aad_managed_service_identity_authentication(
                cluster_url
            )
            client = KustoClient(kcsb)
            client.execute_mgmt("NetDefaultDB", ".show version")
            print("✅ Managed Identity authentication successful.")
            return client
        except Exception as inner_e:
            print(f"❌ Managed Identity auth failed: {inner_e}")
            raise inner_e


def query_adx_database(kql_query: str) -> str:
    """
    Execute a KQL query against ADX with local or cloud-friendly auth (AZ CLI or Managed Identity).
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
        client = create_kusto_client(ADX_CLUSTER_URL)
        response = client.execute(ADX_DATABASE, kql_query)
        df = dataframe_from_result_table(response.primary_results[0])

        if df.empty:
            print("⚠️ DataFrame is empty.")
            return safe_serialize(
                {"summary": "⚠️ Query executed but returned no rows.", "preview": []}
            )

        billing_currency = df.get("BillingCurrency", "USD")
        summary = ""
        matched_summary = False

        if "RegionName" in df.columns and "EffectiveCost" in df.columns:
            region = df["RegionName"].iloc[0]
            cost = df["EffectiveCost"].iloc[0]
            summary = f"📊 Region '{region}' had the highest actual cost of ${cost:,.2f} {billing_currency}."
            matched_summary = True
        elif "ServiceName" in df.columns and "EffectiveCost" in df.columns:
            service = df["ServiceName"].iloc[0]
            cost = df["EffectiveCost"].iloc[0]
            summary = f"💡 The top spending service is '{service}' with a cost of ${cost:,.2f} {billing_currency}."
            matched_summary = True
        elif "ChargePeriodStart" in df.columns and "EffectiveCost" in df.columns:
            summary = (
                f"📈 Monthly cost trend over {len(df)} periods. "
                f"Latest cost: ${df['EffectiveCost'].iloc[-1]:,.2f}."
            )
            matched_summary = True
        elif "AnomalyScore" in df.columns:
            anomalies = df[df["AnomalyScore"].abs() > 2]
            summary = f"🚨 Found {len(anomalies)} anomalies with high AnomalyScore (|score| > 2)."
            matched_summary = True

        if not matched_summary:
            summary = f"✅ ADX query successful. Returned {len(df)} row(s)."

        preview = df.head(50).fillna("").to_dict(orient="records")
        print(f"✅ Returning {len(preview)} preview rows.")

        return safe_serialize({"summary": summary, "preview": preview})

    except Exception as e:
        print(f"❌ Exception in query_adx_database: {e}")
        return safe_serialize({"error": f"❌ Failed to query ADX: {str(e)}"})


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
        snippet = content[:1500].strip().replace("\n", " ")
        filename = re.sub(r"\W+", "-", title.lower()).strip("-") + ".md"
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
    "run_vector_search2": run_vector_search2,
}
