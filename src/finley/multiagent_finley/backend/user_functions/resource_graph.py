import json
import os
import subprocess
from typing import List, Optional
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource.subscriptions import SubscriptionClient
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.resourcegraph.models import QueryRequest
from semantic_kernel.functions import kernel_function
from semantic_kernel.kernel_pydantic import KernelBaseModel
from dotenv import load_dotenv

load_dotenv()

# ---------- Subscription Helpers ----------

def get_env_subscriptions() -> List[str]:
    raw = os.getenv("SUBSCRIPTIONS", "")
    return [s.strip() for s in raw.split(",") if s.strip()]

def load_subscriptions_from_file(path: str = "subscriptions.txt") -> List[str]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        return []

def get_cli_subscriptions() -> List[str]:
    try:
        result = subprocess.run(
            ["az", "account", "list", "--query", "[?state=='Enabled'].id", "-o", "tsv"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip().splitlines()
    except Exception as e:
        print(f"⚠️ Failed to retrieve subscriptions from CLI: {e}")
        return []

def get_default_subscriptions(prefer_file: bool = True) -> List[str]:
    if prefer_file:
        file_subs = load_subscriptions_from_file()
        if file_subs:
            return file_subs

    env_subs = get_env_subscriptions()
    if env_subs:
        return env_subs

    cli_subs = get_cli_subscriptions()
    return cli_subs

# ---------- ARG Query Class ----------

class ARGFunctions(KernelBaseModel):
    """Functions for interacting with Azure Resource Graph."""

    credential: Optional[DefaultAzureCredential] = None
    subscription_client: Optional[SubscriptionClient] = None

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.credential = DefaultAzureCredential()
        self.subscription_client = SubscriptionClient(self.credential)

    @kernel_function(
        description="Query Azure Resource Graph with KQL",
        name="query_arg"
    )
    def query_resource_graph(self, arg_query: str, subscriptions: Optional[List[str]] = None) -> str:
        if subscriptions is None or not subscriptions:
            subscriptions = get_default_subscriptions()

        if not subscriptions:
            return json.dumps({"error": "No subscriptions available or configured."})

        client = ResourceGraphClient(self.credential)

        try:
            request = QueryRequest(query=arg_query, subscriptions=subscriptions)
            result = client.resources(request)

            total = len(result.data)
            summary = f"✅ Found {total} resources."
            preview = result.data[:50] if total > 0 else []

            return json.dumps({
                "summary": summary,
                "preview": preview
            })

        except Exception as e:
            return json.dumps({"error": str(e)})
