from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.core.credentials import AzureKeyCredential
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential
import os
import re

def slugify(title):
    # Convert titles to filename-friendly slugs
    return re.sub(r'\W+', '-', title.lower()).strip('-') + ".md"

def get_embeddings(text):
    """Get embeddings for text using Azure OpenAI"""
    openai_endpoint = os.environ.get("OPEN_AI_ENDPOINT") or os.environ.get("AZURE_OPENAI_ENDPOINT")
    embedding_deployment = os.environ.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-large")
    openai_key = os.environ.get("AZURE_OPENAI_KEY")
    
    if not openai_endpoint or not embedding_deployment:
        print("Warning: OpenAI endpoint or deployment not configured for embeddings")
        return None
    
    try:
        if openai_key:
            client = AzureOpenAI(
                azure_endpoint=openai_endpoint,
                api_key=openai_key,
                api_version="2024-02-01"
            )
        else:
            credential = DefaultAzureCredential()
            client = AzureOpenAI(
                azure_endpoint=openai_endpoint,
                azure_ad_token_provider=lambda: credential.get_token("https://cognitiveservices.azure.com/.default").token,
                api_version="2024-02-01"
            )
        
        # text-embedding-3-large supports dimensions parameter
        response = client.embeddings.create(
            model=embedding_deployment,
            input=[text],
            dimensions=3072  # Match your index dimensions
        )
        
        return response.data[0].embedding
    except Exception as e:
        print(f"Error getting embeddings: {str(e)}")
        return None

def run_vector_search(query_text):
    endpoint = os.environ["AZURE_AI_SEARCH_SERVICE_ENDPOINT"]
    index_name = os.environ["AZURE_AI_SEARCH_INDEX_NAME"]
    key = os.environ["AZURE_SEARCH_ADMIN_KEY"]

    search_client = SearchClient(
        endpoint=endpoint,
        index_name=index_name,
        credential=AzureKeyCredential(key)
    )

    # Get embeddings for the query
    embeddings = get_embeddings(query_text)
    
    if not embeddings:
        # Fallback to text-only search if embeddings fail
        results = search_client.search(
            search_text=query_text,
            select=["title", "content"],
            top=3
        )
    else:
        # Use vector search with VectorizedQuery
        vector_query = VectorizedQuery(
            vector=embeddings,
            k_nearest_neighbors=60,
            fields="contentVector,titleVector"
        )

        results = search_client.search(
            search_text=None,
            vector_queries=[vector_query],
            select=["title", "content"],
            top=3
        )

    output_lines = ["## 🔍 Top Matching Documents\n"]
    source_links = []

    for i, result in enumerate(results, start=1):
        title = result.get("title", f"Document {i}")
        content = result.get("content", "[No content available]")
        snippet = content[:1500].strip().replace('\n', ' ')
        filename = slugify(title)

        score = getattr(result, "@search.score", None)

        output_lines.append(f"### {i}. 📄 **{title}**")
        if score:
            output_lines.append(f"**Relevance Score:** {score:.2f}")
        output_lines.append(f"{snippet}...\n")
        output_lines.append("---")

        # For source list
        source_links.append(f"- [{title}]({filename})")

    # Add sources block
    output_lines.append("\n**Sources:**")
    output_lines.extend(source_links)

    return "\n".join(output_lines)
