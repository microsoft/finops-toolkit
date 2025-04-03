# user_functions/resource_graph.py

import json
import os
from typing import List
from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.resourcegraph.models import QueryRequest
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# ---------- Subscription Helpers ----------

def get_env_subscriptions() -> List[str]:
    """Load subscriptions from .env file (comma-separated)."""
    raw = os.getenv("SUBSCRIPTIONS", "")
    return [s.strip() for s in raw.split(",") if s.strip()]

def load_subscriptions_from_file(path: str = "subscriptions.txt") -> List[str]:
    """Load subscriptions from a local file, one per line."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        return []

def get_all_subscriptions() -> List[str]:
    """Get all enabled subscriptions using Azure CLI (fallback)."""
    try:
        import subprocess
        result = subprocess.run(
            ["az", "account", "list", "--query", "[?state=='Enabled'].id", "-o", "tsv"],
            capture_output=True, text=True
        )
        return result.stdout.strip().splitlines()
    except Exception as e:
        print(f"⚠️ Failed to run az CLI: {e}")
        return []

def get_subscriptions(prefer_file: bool = True) -> List[str]:
    """Main selector: file > .env > CLI"""
    if prefer_file:
        subs_from_file = load_subscriptions_from_file()
        if subs_from_file:
            return subs_from_file

    subs_from_env = get_env_subscriptions()
    if subs_from_env:
        return subs_from_env

    return get_all_subscriptions()

# ---------- Query Function ----------

def query_resource_graph(query: str, subscriptions: List[str] = None) -> str:
    """
    Run a Kusto query on Azure Resource Graph to explore resources like VMs, storage, disks, or network interfaces.
    Use this when the user is asking about Azure resources and infrastructure metadata.

    
    Args:
        query (str): The Kusto query string to execute.
        subscriptions (List[str], optional): Subscription IDs to target.

    Returns:
        str: A JSON string with a 'summary' and a 'preview' of the results.
    """

    try:
        if not subscriptions:
            subscriptions = get_subscriptions()

        if not subscriptions:
            raise ValueError("❌ No subscriptions found. Set SUBSCRIPTIONS in .env or provide subscriptions.txt.")

        credential = DefaultAzureCredential()
        client = ResourceGraphClient(credential)

        request = QueryRequest(query=query, subscriptions=subscriptions)
        result = client.resources(request)

        total = len(result.data)
        summary = f"✅ Query executed successfully. Found {total} resources."
        preview = result.data[:50] if total > 0 else []

        return json.dumps({
            "summary": summary,
            "preview": preview
        })

    except Exception as e:
        return json.dumps({"error": str(e)})
