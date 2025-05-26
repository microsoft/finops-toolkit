"""
Test script for vector search functionality
"""
import os
import sys
from dotenv import load_dotenv

# Add the parent directory to the path so we can import the function
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from user_functions.vector_search_enhanced import run_vector_search

# Load environment variables
load_dotenv()

def test_search():
    """Test the search functionality with various queries"""
    
    # Test queries
    test_queries = [
        "What is FinOps?",
        "How to allocate cloud costs?",
        "What are the FinOps principles?",
        "Cloud cost optimization strategies",
        "FinOps maturity model",
        "Show me information about anomaly detection in cloud costs"
    ]
    
    print("Testing Vector Search with Semantic Configuration")
    print("=" * 50)
    
    for query in test_queries:
        print(f"\nQuery: '{query}'")
        print("-" * 50)
        
        try:
            # Test with semantic search
            print("\n--- WITH SEMANTIC SEARCH ---")
            results = run_vector_search(query, use_semantic=True)
            print(results)
            
            # Test without semantic search
            print("\n--- WITHOUT SEMANTIC SEARCH ---")
            results = run_vector_search(query, use_semantic=False)
            print(results)
            
            print("\n" + "=" * 50)
            
        except Exception as e:
            print(f"Error: {str(e)}")
            import traceback
            traceback.print_exc()
    
def test_single_query(query):
    """Test a single query"""
    print(f"Testing query: '{query}'")
    print("-" * 50)
    
    try:
        results = run_vector_search(query)
        print(results)
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    # Check if environment variables are set
    print("Environment Check:")
    print(f"Search Endpoint: {os.getenv('AZURE_AI_SEARCH_SERVICE_ENDPOINT', 'NOT SET')}")
    print(f"Index Name: {os.getenv('AZURE_SEARCH_INDEX', 'NOT SET')}")
    print(f"Has API Key: {'Yes' if os.getenv('AZURE_SEARCH_ADMIN_KEY') else 'No'}")
    print()
    
    # Run tests
    if len(sys.argv) > 1:
        # Test specific query from command line
        query = " ".join(sys.argv[1:])
        test_single_query(query)
    else:
        # Run default test queries
        test_search()
