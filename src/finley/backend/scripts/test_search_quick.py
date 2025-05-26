"""
Quick test to verify search is working
"""
import os
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery, QueryType
from azure.core.credentials import AzureKeyCredential
from dotenv import load_dotenv

load_dotenv()

def quick_test():
    endpoint = os.getenv("AZURE_AI_SEARCH_SERVICE_ENDPOINT")
    index_name = os.getenv("AZURE_AI_SEARCH_INDEX")
    key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
    
    print(f"Testing search on index: {index_name}")
    print(f"Endpoint: {endpoint}")
    
    if not all([endpoint, index_name, key]):
        print("ERROR: Missing environment variables")
        return
    
    try:
        # Create client
        search_client = SearchClient(
            endpoint=endpoint,
            index_name=index_name,
            credential=AzureKeyCredential(key)
        )
        
        # Simple text search
        print("\n1. Testing basic text search...")
        results = search_client.search(
            search_text="FinOps",
            select=["title", "content"],
            top=3
        )
        
        count = 0
        for result in results:
            count += 1
            print(f"   Found: {result.get('title', 'No title')}")
        
        print(f"   Total results: {count}")
        
        # Vector search
        print("\n2. Testing vector search...")
        vector_query = VectorizableTextQuery(
            text="What is FinOps?",
            k_nearest_neighbors=5,
            fields="contentVector,titleVector"
        )
        
        results = search_client.search(
            search_text=None,
            vector_queries=[vector_query],
            select=["title"],
            top=3
        )
        
        count = 0
        for result in results:
            count += 1
            print(f"   Found: {result.get('title', 'No title')}")
        
        print(f"   Total results: {count}")
        
        # Semantic search
        print("\n3. Testing semantic search...")
        results = search_client.search(
            search_text="What is FinOps?",
            query_type=QueryType.SEMANTIC,
            semantic_configuration_name="finops-semantic-config",
            select=["title"],
            top=3
        )
        
        count = 0
        for result in results:
            count += 1
            print(f"   Found: {result.get('title', 'No title')}")
            if hasattr(result, "@search.semantic_score"):
                score = getattr(result, "@search.semantic_score")
                print(f"   Semantic Score: {score}")
        
        print(f"   Total results: {count}")
        
        print("\n✅ All tests completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    quick_test()
