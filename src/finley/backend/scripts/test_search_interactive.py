"""
Interactive test for vector search
"""
import os
import sys
from dotenv import load_dotenv

# Add the parent directory to the path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from user_functions.vector_search_enhanced import run_vector_search

# Load environment variables
load_dotenv()

def interactive_test():
    """Interactive testing of vector search"""
    
    print("Vector Search Test Tool")
    print("=====================")
    print(f"Index: {os.getenv('AZURE_AI_SEARCH_INDEX', 'NOT SET')}")
    print(f"Endpoint: {os.getenv('AZURE_AI_SEARCH_SERVICE_ENDPOINT', 'NOT SET')}")
    print("\nType 'quit' to exit")
    print("Add '!no-semantic' to disable semantic search")
    print()
    
    while True:
        query = input("Enter search query: ").strip()
        
        if query.lower() == 'quit':
            break
            
        if not query:
            continue
            
        # Check for flags
        use_semantic = True
        if query.endswith('!no-semantic'):
            use_semantic = False
            query = query.replace('!no-semantic', '').strip()
        
        try:
            print("\nSearching...")
            results = run_vector_search(query, use_semantic=use_semantic)
            print("\nResults:")
            print(results)
            print("\n" + "="*50 + "\n")
        except Exception as e:
            print(f"Error: {str(e)}")
            import traceback
            traceback.print_exc()
            print()

if __name__ == "__main__":
    interactive_test()
