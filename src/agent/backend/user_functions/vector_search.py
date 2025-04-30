from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from azure.core.credentials import AzureKeyCredential
import os
import re



def slugify(title):
    # Convert titles to filename-friendly slugs
    return re.sub(r'\W+', '-', title.lower()).strip('-') + ".md"

def run_vector_search(query_text):
    endpoint = os.environ["AZURE_AI_SEARCH_SERVICE_ENDPOINT"]
    index_name = os.environ["AZURE_AI_SEARCH_INDEX_NAME"]
    key = os.environ["AZURE_SEARCH_ADMIN_KEY"]


    search_client = SearchClient(
        endpoint=endpoint,
        index_name=index_name,
        credential=AzureKeyCredential(key)
    )

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

