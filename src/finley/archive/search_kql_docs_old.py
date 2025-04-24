import os
from dotenv import load_dotenv
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
from azure.search.documents.models import VectorizableTextQuery
import openai
import logging

load_dotenv()
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

# Load environment variables
endpoint = os.getenv("AZURE_AI_SEARCH_SERVICE_ENDPOINT")
api_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
index_name = os.getenv("AZURE_SEARCH_INDEX_KQL")
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY")
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
AZURE_OPENAI_API_VERSION = "2023-05-15"

def search_kql_docs_hybrid(query: str, top_k: int = 3) -> list[dict]:
    """Performs hybrid (vector + semantic) search over indexed KQL docs using Azure AI Search and OpenAI embeddings."""

    if not query or not query.strip():
        logger.warning("⚠️ Empty query provided to hybrid search.")
        return []

    # Initialize clients
    search_client = SearchClient(endpoint=endpoint, index_name=index_name, credential=AzureKeyCredential(api_key))
    embedding_client = openai.AzureOpenAI(
        api_key=AZURE_OPENAI_KEY,
        api_version=AZURE_OPENAI_API_VERSION,
        azure_endpoint=AZURE_OPENAI_ENDPOINT,
    )

    try:
        embedding_response = embedding_client.embeddings.create(
            input=[query],
            model=AZURE_OPENAI_EMBEDDING_DEPLOYMENT,
        )
        embedding = embedding_response.data[0].embedding
    except Exception as e:
        logger.error(f"❌ Failed to generate embedding for query: {e}")
        return []

    # Prepare vector query
    vector_query = VectorizableTextQuery(
        text=query,  # required even for vector + hybrid search
        vector=embedding,
        k_nearest_neighbors=100,
        fields="contentVector"
    )

    try:
        results = search_client.search(
            search_text=query,
            vector_queries=[vector_query],
            select=["title", "content", "source_url"],
            top=top_k,
            query_type="semantic",
            semantic_configuration_name="my-semantic-config"
        )
    except Exception as e:
        logger.error(f"❌ Search operation failed: {e}")
        return []

    seen_urls = set()
    output = []

    for result in results:
        url = result.get("source_url")
        if not url or url in seen_urls:
            continue

        content_snippet = result.get("content", "").strip()
        title = result.get("title", "").strip()

        if not content_snippet:
            continue

        output.append({
            "title": title,
            "url": url,
            "content": content_snippet[:500]
        })
        seen_urls.add(url)

    if not output:
        logger.warning("⚠️ No relevant documents found for query.")

    return output
