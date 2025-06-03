from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery, QueryType
from azure.core.credentials import AzureKeyCredential
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential
import os
import re

def slugify(title):
    """Convert a title string to a URL-friendly slug."""
    if not title:
        return "unnamed-document"
    return re.sub(r'\W+', '-', title.lower()).strip('-')

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
                api_version="2024-12-01-preview"
            )
        else:
            credential = DefaultAzureCredential()
            client = AzureOpenAI(
                azure_endpoint=openai_endpoint,
                azure_ad_token_provider=lambda: credential.get_token("https://cognitiveservices.azure.com/.default").token,
                api_version="2024-12-01-preview"
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

def run_vector_search(query_text, use_semantic=True):
    # Use the environment variable names that match your .env file
    endpoint = os.environ.get("AZURE_AI_SEARCH_SERVICE_ENDPOINT") or os.environ.get("AZURE_SEARCH_ENDPOINT")
    index_name = os.environ.get("AZURE_AI_SEARCH_INDEX") or os.environ.get("AZURE_SEARCH_INDEX")
    key = os.environ.get("AZURE_SEARCH_ADMIN_KEY") or os.environ.get("AZURE_SEARCH_KEY")
    
    if not endpoint:
        raise ValueError("Missing required environment variable: AZURE_AI_SEARCH_SERVICE_ENDPOINT or AZURE_SEARCH_ENDPOINT")
    if not index_name:
        raise ValueError("Missing required environment variable: AZURE_AI_SEARCH_INDEX or AZURE_SEARCH_INDEX")
    if not key:
        raise ValueError("Missing required environment variable: AZURE_SEARCH_ADMIN_KEY or AZURE_SEARCH_KEY")

    # Now that we've verified these aren't None, we can safely use them as strings
    search_client = SearchClient(
        endpoint=endpoint,
        index_name=index_name,
        credential=AzureKeyCredential(key)
    )
    
    # Get embeddings for the query
    vector_queries = []
    embeddings = get_embeddings(query_text)
    
    if embeddings:
        # Create VectorizedQuery
        vector_queries = [
            VectorizedQuery(
                vector=embeddings,
                k_nearest_neighbors=50,
                fields="titleVector,contentVector"
            )
        ]
    
    # Configure search parameters with only the essential fields that are likely to exist
    search_params = {
        "search_text": query_text if use_semantic else None,  # Text query for semantic search
        "select": ["title", "content", "section", "category", "filepath"],  # Only include fields that are known to exist
        "top": 10,
    }
    
    # Add vector queries if available
    if vector_queries:
        search_params["vector_queries"] = vector_queries
    
    # Add semantic configuration if enabled
    if use_semantic:
        search_params.update({
            "query_type": QueryType.SEMANTIC,
            "semantic_configuration_name": "finops-semantic-config",
            "include_total_count": True,
            "query_caption": "extractive",
            "query_answer": "extractive",
        })

    results = search_client.search(**search_params)

    output_lines = ["## 🔍 Top Matching Documents\n"]
    source_links = []
    cited_snippets = []
    result_count = 0

    for i, result in enumerate(results, start=1):
        if result_count >= 3:
            break
            
        title = result.get("title", f"Document {i}")
        content = result.get("content", "[No content available]")
        section = result.get("section", "")
        category = result.get("category", "")
        filepath = result.get("filepath", "")
        
        # Generate a chunk ID based on index
        chunk_id = f"chunk-{i}"
                
        score = getattr(result, "@search.score", None)
        semantic_score = getattr(result, "@search.semantic_score", None)
        
        captions = getattr(result, "@search.captions", None)
        if captions and len(captions) > 0:
            snippet = captions[0].text
            if hasattr(captions[0], 'highlights') and captions[0].highlights:
                snippet = captions[0].highlights
        else:
            snippet = content[:1500].strip().replace('\n', ' ')
        
        filename = slugify(title)

        # Format citation ID
        citation_id = f"[{i}]"
        
        # Add document header
        output_lines.append(f"### {i}. 📄 **{title}**")
        if section:
            output_lines.append(f"**Section:** {section}")
        if category:
            output_lines.append(f"**Category:** {category}")
        if semantic_score:
            output_lines.append(f"**Semantic Score:** {semantic_score:.2f}")
        elif score:
            output_lines.append(f"**Relevance Score:** {score:.2f}")
        
        # Add quoted and cited snippet with enhanced formatting for better citation handling
        cleaned_snippet = snippet.replace('\n', ' ').strip()
        if len(cleaned_snippet) > 300:
            cleaned_snippet = cleaned_snippet[:300] + "..."
        
        # Add citation reference that will be processed by the CitationHandler
        cited_snippet = f"> {cleaned_snippet} {citation_id}"
        output_lines.append(cited_snippet)
        output_lines.append("")
        output_lines.append("---")
        
        # Ensure filepath and chunkId are included in the citation data
        if not filepath:
            filepath = "[Filepath not available]"

        # Store citation with more information about where it's coming from
        cited_snippets.append({
            "id": citation_id,
            "title": title,
            "section": section,
            "filepath": filepath,
            "filename": filename,
            "document_name": title,  # Use title as document name since we don't have a separate field
            "chunkId": chunk_id,  # Keep as chunkId to match frontend expectation
            "content_sample": cleaned_snippet,
            "source_info": filepath.split('/')[-1] if filepath else title
        })
        
        # Just count the result, we'll handle citations differently
        result_count += 1

    # Check for semantic answers in the results
    answers = []
    if use_semantic:
        try:
            if hasattr(results, 'get_answers'):
                answers = results.get_answers()
            # The _answers attribute is not reliably accessible in the SearchItemPaged type
        except Exception as e:
            print(f"Warning: Could not retrieve semantic answers: {str(e)}")
    
    if answers:
        output_lines.insert(1, "### 💡 Direct Answer\n")
        for answer in answers[:1]:
            answer_text = answer.text if answer.text is not None else ""
            
            # Add citations to the direct answer if possible
            for snippet in cited_snippets:
                # Check if the title appears in the answer text
                if answer_text and snippet.get("title") and snippet["title"].lower() in answer_text.lower():
                    # Make sure we add the citation at the end if it doesn't already exist
                    if snippet["id"] not in answer_text:
                        answer_text += f" {snippet['id']}"
            
            output_lines.insert(2, f"{answer_text}\n")
            output_lines.insert(3, "---\n")

    # Add a more prominent citation section
    output_lines.append("\n## 📚 Citations and References")
    for snippet in cited_snippets:
        citation_line = f"{snippet['id']} {snippet['title']}"
        if snippet.get('section'):
            citation_line += f", Section: {snippet['section']}"
        
        # Add filepath info in a clean way
        if snippet.get('filepath'):
            citation_path = snippet['filepath'].split('/')
            if len(citation_path) > 0:
                citation_line += f", File: {citation_path[-1]}"
            
        output_lines.append(citation_line)

    return {
        "answer": "\n".join(output_lines),
        "citations": [
            {
                "id": snippet["id"].strip("[]"),
                "title": snippet["title"],
                "section": snippet.get("section", ""),
                "filepath": snippet.get("filepath", ""),
                "document_name": snippet.get("document_name", snippet["title"]),
                "chunkId": snippet.get("chunkId", ""),
                "content": snippet.get("content_sample", "")
            }
            for snippet in cited_snippets
        ]
    }
# For backward compatibility
def run_vector_search_legacy(query_text):
    """Original function without semantic search"""
    return run_vector_search(query_text, use_semantic=False)
