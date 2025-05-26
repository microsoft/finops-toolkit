"""
Script to create Azure AI Search index for FinOps documentation.
Compatible with azure-search-documents 11.6.0b7
"""
import os
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    SimpleField,
    SearchableField,
    VectorSearch,
    HnswAlgorithmConfiguration,
    HnswParameters,
    VectorSearchProfile,
    VectorSearchAlgorithmKind,
    SemanticConfiguration,
    SemanticPrioritizedFields,
    SemanticField,
    SemanticSearch,
)
from azure.core.credentials import AzureKeyCredential
from dotenv import load_dotenv

load_dotenv()

def create_search_index():
    """Create the Azure AI Search index for FinOps documentation."""
    
    # Configuration
    endpoint = os.getenv("AZURE_AI_SEARCH_SERVICE_ENDPOINT")
    admin_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
    index_name = os.getenv("AZURE_SEARCH_INDEX", "finops-docs-index")
    embedding_dimensions = 3072  # text-embedding-3-large dimensions
    
    if not endpoint or not admin_key:
        print("ERROR: Missing required environment variables:")
        print("  AZURE_AI_SEARCH_SERVICE_ENDPOINT")
        print("  AZURE_SEARCH_ADMIN_KEY")
        return
    
    # Initialize the search index client
    index_client = SearchIndexClient(
        endpoint=endpoint,
        credential=AzureKeyCredential(admin_key)
    )
    
    # Define the search fields
    fields = [
        SimpleField(
            name="id",
            type=SearchFieldDataType.String,
            key=True,
            filterable=True
        ),
        SearchableField(
            name="title",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
            sortable=True,
            facetable=True
        ),
        SimpleField(
            name="chunkIndex",
            type=SearchFieldDataType.Int32,
            sortable=True,
            filterable=True
        ),
        SearchableField(
            name="content",
            type=SearchFieldDataType.String,
            searchable=True,
            analyzer_name="standard.lucene"
        ),
        SearchableField(
            name="filepath",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
            facetable=True
        ),
        SearchableField(
            name="section",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
            facetable=True
        ),
        SearchableField(
            name="category",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
            facetable=True
        ),
        SearchField(
            name="titleVector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=embedding_dimensions,
            vector_search_profile_name="title-profile"
        ),
        SearchField(
            name="contentVector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=embedding_dimensions,
            vector_search_profile_name="content-profile"
        ),
    ]
    
    # Configure vector search
    vector_search = VectorSearch(
        algorithms=[
            HnswAlgorithmConfiguration(
                name="hnsw-algorithm",
                kind=VectorSearchAlgorithmKind.HNSW,
                parameters=HnswParameters(
                    m=4,
                    ef_construction=400,
                    ef_search=500,
                    metric="cosine"
                )
            )
        ],
        profiles=[
            VectorSearchProfile(
                name="title-profile",
                algorithm_configuration_name="hnsw-algorithm",
            ),
            VectorSearchProfile(
                name="content-profile",
                algorithm_configuration_name="hnsw-algorithm",
            )
        ]
    )
    
    # Configure semantic search
    semantic_search = SemanticSearch(
        configurations=[
            SemanticConfiguration(
                name="finops-semantic-config",
                prioritized_fields=SemanticPrioritizedFields(
                    title_field=SemanticField(field_name="title"),
                    content_fields=[
                        SemanticField(field_name="content"),
                        SemanticField(field_name="section")
                    ],
                    keywords_fields=[
                        SemanticField(field_name="category"),
                        SemanticField(field_name="filepath")
                    ]
                )
            )
        ]
    )
    
    # Create the search index
    index = SearchIndex(
        name=index_name,
        fields=fields,
        vector_search=vector_search,
        semantic_search=semantic_search
    )
    
    # Delete existing index if it exists
    try:
        index_client.delete_index(index_name)
        print(f"Deleted existing index: {index_name}")
    except Exception:
        print(f"No existing index to delete: {index_name}")
    
    # Create the index
    result = index_client.create_index(index)
    print(f"Created search index: {result.name}")
    print(f"Fields: {[field.name for field in result.fields]}")
    
    return result

if __name__ == "__main__":
    create_search_index()
