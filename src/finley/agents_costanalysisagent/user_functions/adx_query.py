import os
import json
from dotenv import load_dotenv
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table

# Load environment variables
load_dotenv()

def query_adx_database(cluster_url: str, database: str, kql_query: str) -> str:
    """
    Query Azure Data Explorer (ADX) using Azure CLI authentication.

    Args:
        cluster_url (str): Full cluster URL (e.g., https://yourcluster.kusto.windows.net)
        database (str): Target ADX database
        kql_query (str): Kusto Query Language string

    Returns:
        str: JSON with 'summary' and 'preview' of query results
    """
    try:
        # Authenticate using Azure CLI session
        kcsb = KustoConnectionStringBuilder.with_az_cli_authentication(cluster_url)

        # Connect and execute query
        client = KustoClient(kcsb)
        response = client.execute(database, kql_query)

        # Convert result to DataFrame
        result_table = response.primary_results[0]
        df = dataframe_from_result_table(result_table)

        # Prepare summary and preview
        rows = df.to_dict(orient="records")
        summary = f"✅ ADX query successful. Returned {len(rows)} rows."
        preview = rows[:50]

        return json.dumps({
            "summary": summary,
            "preview": preview
        })

    except Exception as e:
        return json.dumps({
            "error": f"❌ Failed to query ADX: {str(e)}"
        })