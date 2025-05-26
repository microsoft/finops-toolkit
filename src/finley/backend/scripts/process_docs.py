"""
Script to process markdown files using your existing Azure OpenAI endpoint.
This version includes better error handling and diagnostics.
"""
import os
import glob
import json
import tiktoken
import re
from typing import List, Dict, Any
from pathlib import Path

from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
import time

load_dotenv()

# === Configuration ===
# Use your existing OpenAI endpoint from .env
azure_openai_endpoint = os.getenv("OPEN_AI_ENDPOINT")
# You'll need to add this to your .env - the name of your embedding deployment
azure_openai_embedding_deployment = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-ada-002")
azure_openai_api_version = "2024-02-01"
azure_openai_key = os.getenv("AZURE_OPENAI_KEY")  # Add this to .env if needed

# Azure AI Search configuration - add these to your .env
search_endpoint = os.getenv("AZURE_AI_SEARCH_SERVICE_ENDPOINT")
search_index_name = os.getenv("AZURE_SEARCH_INDEX", "finops-docs-index")
search_api_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")

# Base folder for markdown files from the root
base_folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))), "docs-mslearn")

# Initialize tokenizer
encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")  # Use a compatible tokenizer

print("Configuration:")
print(f"OpenAI Endpoint: {azure_openai_endpoint}")
print(f"Embedding Deployment: {azure_openai_embedding_deployment}")
print(f"Search Endpoint: {search_endpoint}")
print(f"Search Index: {search_index_name}")
print(f"Base Folder: {base_folder}")
print()

if not azure_openai_endpoint:
    print("ERROR: OPEN_AI_ENDPOINT not found in .env")
    exit(1)

if not search_endpoint:
    print("WARNING: Azure AI Search not configured. Add these to .env:")
    print("  AZURE_AI_SEARCH_SERVICE_ENDPOINT=https://your-search.search.windows.net")
    print("  AZURE_SEARCH_ADMIN_KEY=your-admin-key")
    print()

class MarkdownProcessor:
    """Process markdown files for search indexing."""
    
    def __init__(self, base_folder: str):
        self.base_folder = base_folder
        
    def extract_metadata(self, filepath: str, content: str) -> Dict[str, str]:
        """Extract metadata from file path and content."""
        rel_path = os.path.relpath(filepath, self.base_folder)
        parts = rel_path.split(os.sep)
        
        category = parts[0] if len(parts) > 0 else "general"
        section = parts[1] if len(parts) > 1 else ""
        
        title_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
        title = title_match.group(1) if title_match else os.path.basename(filepath).replace('.md', '').replace('-', ' ').title()
        
        return {
            "title": title,
            "filepath": filepath.replace(os.sep, '/'),
            "category": category,
            "section": section
        }
    
    def split_text_into_chunks(self, text: str, max_tokens: int = 800) -> List[str]:
        """Split text into chunks based on token count."""
        sentences = re.split(r'(?<=[.!?])\s+', text)
        chunks = []
        current_chunk = []
        current_tokens = 0
        
        for sentence in sentences:
            sentence_tokens = len(encoding.encode(sentence))
            
            if current_tokens + sentence_tokens > max_tokens and current_chunk:
                chunks.append(' '.join(current_chunk))
                current_chunk = [sentence]
                current_tokens = sentence_tokens
            else:
                current_chunk.append(sentence)
                current_tokens += sentence_tokens
        
        if current_chunk:
            chunks.append(' '.join(current_chunk))
        
        return [chunk.strip() for chunk in chunks if chunk.strip()]
    
    def process_files(self) -> List[Dict[str, Any]]:
        """Process all markdown files."""
        md_files = glob.glob(os.path.join(self.base_folder, "**/*.md"), recursive=True)
        documents = []
        
        print(f"Found {len(md_files)} markdown files")
        
        for file_path in md_files:
            print(f"Processing: {os.path.basename(file_path)}")
            
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                if not content.strip():
                    continue
                
                metadata = self.extract_metadata(file_path, content)
                chunks = self.split_text_into_chunks(content)
                
                for i, chunk in enumerate(chunks):
                    # Create safe document ID by encoding the path
                    rel_path = os.path.relpath(file_path, self.base_folder)
                    # Replace any problematic characters
                    safe_path = rel_path.replace('\\', '_').replace('/', '_').replace(':', '_').replace(' ', '_')
                    safe_path = safe_path.replace('.md', '')
                    doc_id = f"{safe_path}_chunk{i}"
                    
                    documents.append({
                        "id": doc_id,
                        "title": metadata["title"],
                        "chunkIndex": i,
                        "content": chunk,
                        "filepath": metadata["filepath"],
                        "section": metadata.get("section", ""),
                        "category": metadata["category"],
                    })
            
            except Exception as e:
                print(f"Error processing {file_path}: {str(e)}")
        
        return documents

def create_embeddings(documents: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Add embeddings to documents."""
    print("\nCreating embeddings...")
    
    try:
        # Initialize Azure OpenAI client
        if azure_openai_key:
            client = AzureOpenAI(
                azure_endpoint=azure_openai_endpoint,
                api_key=azure_openai_key,
                api_version=azure_openai_api_version
            )
        else:
            # Use managed identity
            credential = DefaultAzureCredential()
            client = AzureOpenAI(
                azure_endpoint=azure_openai_endpoint,
                azure_ad_token_provider=lambda: credential.get_token("https://cognitiveservices.azure.com/.default").token,
                api_version=azure_openai_api_version
            )
        
        # Test connection and get embedding dimensions
        print("Testing OpenAI connection...")
        test_response = client.embeddings.create(
            model=azure_openai_embedding_deployment,
            input=["test"]
        )
        actual_dimensions = len(test_response.data[0].embedding)
        print(f"✓ Connection successful! Embedding dimension: {actual_dimensions}")
        
        # If dimensions don't match, we need to adjust
        expected_dimensions = 3072
        if actual_dimensions != expected_dimensions:
            print(f"WARNING: Index expects {expected_dimensions} dimensions but model produces {actual_dimensions}")
            print("Your model might be text-embedding-3-large (3072) instead of text-embedding-ada-002 (1536)")
            
            # For text-embedding-3-large, we can specify dimensions
            if actual_dimensions == 3072:
                print("Attempting to use dimensions parameter...")
                test_response2 = client.embeddings.create(
                    model=azure_openai_embedding_deployment,
                    input=["test"],
                    dimensions=expected_dimensions
                )
                if len(test_response2.data[0].embedding) == expected_dimensions:
                    print(f"✓ Successfully reduced dimensions to {expected_dimensions}")
                    use_dimensions = True
                else:
                    print("ERROR: Cannot adjust dimensions. You may need to recreate the index or use a different model.")
                    return documents
            else:
                print("ERROR: Unexpected embedding dimensions. Check your model deployment.")
                return documents
        else:
            use_dimensions = False
        
    except Exception as e:
        print(f"Error connecting to Azure OpenAI: {str(e)}")
        return documents
    
    # Process documents
    batch_size = 5
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        print(f"Processing batch {i//batch_size + 1} of {(len(documents)-1)//batch_size + 1}")
        
        for doc in batch:
            try:
                # Create embeddings with or without dimensions parameter
                if use_dimensions:
                    title_embedding = client.embeddings.create(
                        model=azure_openai_embedding_deployment,
                        input=[doc["title"]],
                        dimensions=expected_dimensions
                    ).data[0].embedding
                    
                    content_embedding = client.embeddings.create(
                        model=azure_openai_embedding_deployment,
                        input=[doc["content"]],
                        dimensions=expected_dimensions
                    ).data[0].embedding
                else:
                    title_embedding = client.embeddings.create(
                        model=azure_openai_embedding_deployment,
                        input=[doc["title"]]
                    ).data[0].embedding
                    
                    content_embedding = client.embeddings.create(
                        model=azure_openai_embedding_deployment,
                        input=[doc["content"]]
                    ).data[0].embedding
                
                doc["titleVector"] = title_embedding
                doc["contentVector"] = content_embedding
                
                # Rate limiting
                time.sleep(0.1)
                
            except Exception as e:
                print(f"Error creating embeddings for {doc['id']}: {str(e)}")
    
    return documents

def upload_to_search(documents: List[Dict[str, Any]]):
    """Upload documents to Azure AI Search with better error handling."""
    if not search_endpoint or not search_api_key:
        print("\n⚠️  Azure AI Search not configured. Skipping upload.")
        print("Add these to your .env file to enable search:")
        print("  AZURE_AI_SEARCH_SERVICE_ENDPOINT=https://your-search.search.windows.net")
        print("  AZURE_SEARCH_ADMIN_KEY=your-admin-key")
        return
    
    valid_documents = [doc for doc in documents if "titleVector" in doc and "contentVector" in doc]
    print(f"\nUploading {len(valid_documents)} documents to Azure AI Search...")
    
    if not valid_documents:
        print("No documents with embeddings to upload!")
        return
    
    try:
        from azure.search.documents import SearchClient
        
        search_credential = AzureKeyCredential(search_api_key)
        
        # Debug: Print sample document
        print("\nSample document structure:")
        sample = valid_documents[0]
        print(f"  ID: {sample['id']}")
        print(f"  Title: {sample['title']}")
        print(f"  Content length: {len(sample['content'])}")
        print(f"  Title vector length: {len(sample['titleVector'])}")
        print(f"  Content vector length: {len(sample['contentVector'])}")
        
        # Create a search client
        search_client = SearchClient(
            endpoint=search_endpoint,
            index_name=search_index_name,
            credential=search_credential
        )
        
        # Upload documents in batches
        batch_size = 10
        for i in range(0, len(valid_documents), batch_size):
            batch = valid_documents[i:i + batch_size]
            print(f"Uploading batch {i//batch_size + 1} of {(len(valid_documents)-1)//batch_size + 1}")
            
            try:
                result = search_client.upload_documents(documents=batch)
                success_count = sum(1 for r in result if r.succeeded)
                print(f"  Successfully uploaded {success_count} documents in this batch")
            except Exception as batch_error:
                print(f"  Error in batch: {str(batch_error)}")
        
        print(f"\n✓ Upload complete for index '{search_index_name}'")
        
    except Exception as e:
        print(f"\n❌ Error during upload: {str(e)}")
        print("\nDebug information:")
        print(f"  Endpoint: {search_endpoint}")
        print(f"  Index: {search_index_name}")
        print(f"  Has API Key: {'Yes' if search_api_key else 'No'}")

def main():
    """Main function to process and index markdown documents."""
    print("Starting markdown processing...\n")
    
    # Process markdown files
    processor = MarkdownProcessor(base_folder)
    documents = processor.process_files()
    print(f"\nFound {len(documents)} document chunks")
    
    # Add embeddings
    documents_with_embeddings = create_embeddings(documents)
    
    # Count successful embeddings
    success_count = sum(1 for doc in documents_with_embeddings if "titleVector" in doc)
    print(f"\n✓ Created embeddings for {success_count}/{len(documents)} documents")
    
    # Upload to Azure AI Search
    if documents_with_embeddings:
        upload_to_search(documents_with_embeddings)
    
    print("\n✅ Processing complete!")

if __name__ == "__main__":
    main()
