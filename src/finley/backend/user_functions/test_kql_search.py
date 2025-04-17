import os
from dotenv import load_dotenv
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
import openai
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.models import VectorizableTextQuery

from azure.search.documents.indexes.models import (
    SimpleField,
    SearchFieldDataType,
    SearchableField,
    SearchField,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    SemanticConfiguration,
    SemanticPrioritizedFields,
    SemanticField,
    SemanticSearch,
    SearchIndex,
    AzureOpenAIVectorizer,
    AzureOpenAIVectorizerParameters,
    VectorSearchVectorizer
)
# Load env variables
load_dotenv()

# Pull config from .env
endpoint = os.getenv("AZURE_AI_SEARCH_SERVICE_ENDPOINT")
api_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
index_name = os.getenv("AZURE_SEARCH_INDEX_KQL")
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY")
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
AZURE_OPENAI_API_VERSION = "2023-05-15"

print("🔍 Endpoint:", endpoint)
print("🔍 API Key present:", bool(api_key))
print("🔍 Index name:", index_name)
print("🔍 OpenAI Endpoint:", AZURE_OPENAI_ENDPOINT)
print("🔍 OpenAI Key present:", bool(AZURE_OPENAI_KEY))
print("🔍 Embedding Deployment:", AZURE_OPENAI_EMBEDDING_DEPLOYMENT)

def search_kql_docs_hybrid(query: str, top_k: int = 3) -> list[dict]:
    try:
        # Initialize SearchClient
        search_client = SearchClient(
            endpoint=endpoint,
            index_name=index_name,
            credential=AzureKeyCredential(api_key)
        )
        print("✅ Connected to Azure Search")

        vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=100, fields="contentVector")

        results = search_client.search(  
            search_text=query,
            vector_queries= [vector_query],
            select=["title", "content"],
            top=top_k
        )  

        output = []
        for result in results:
            output.append({
                "title": result.get("title"),
                "url": result.get("source_url"),
                "content": result.get("content", "")[:500]
            })

        return output

    except Exception as e:
        print(f"❌ ERROR: {e}")
        return []

if __name__ == "__main__":
    query = "how to use where clause in KQL"
    print(f"🔎 Running test query: '{query}'\n")
    results = search_kql_docs_hybrid(query)
    if results:
        print("\n🔹 Top Results:")
        for i, r in enumerate(results, 1):
            print(f"\n{i}. {r['title']}\n{r['url']}\n{r['content']}")
    else:
        print("⚠️ No results returned.")




  
# Print function
def print_results(results):
    for result in results:
        print(f"\n📄 {result['title']}\n{result['content'][:500]}...\n---")

print_results(results)