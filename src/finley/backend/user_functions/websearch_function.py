# FinOps Toolkit Expert with Tavily Web Search Integration
import os
import re
import json
from pathlib import Path
from dotenv import load_dotenv
from azure.ai.inference import ChatCompletionsClient
from azure.ai.inference.models import SystemMessage, UserMessage
from azure.core.credentials import AzureKeyCredential
import os
import re
from dotenv import load_dotenv
from azure.ai.inference import ChatCompletionsClient
from azure.ai.inference.models import SystemMessage, UserMessage
from azure.core.credentials import AzureKeyCredential

# Load environment
load_dotenv()
endpoint = os.getenv("AZURE_INFERENCE_ENDPOINT")
key = os.getenv("AZURE_INFERENCE_KEY")
model_name = os.getenv("MODEL_NAMEDS", "DeepSeek-R1")

# Initialize client
try:
    client = ChatCompletionsClient(
        endpoint=endpoint, # type: ignore
        credential=AzureKeyCredential(key), # type: ignore
        headers={"x-ms-model-mesh-model-name": model_name}  # Add the model name in the header
    )
    print("✅ Client initialized | Model:", client.get_model_info().model_name)
except Exception as e:
    print("❌ Initialization failed:", e)
# Load environment variables
notebook_path = Path().absolute()
parent_dir = notebook_path.parent.parent.parent  # Going back to the root
load_dotenv(parent_dir / '.env')

print("Initializing DeepSeek-R1 FinOps Toolkit Expert with Tavily Search...")

# Install requirements if needed
try:
    import tavily
    print("✅ Tavily module already installed")
except ImportError:
    print("Installing Tavily Python SDK...")
    import pip
    pip.main(['install', 'tavily-python'])
    import tavily
    print("✅ Tavily module installed successfully")

try:
    # Initialize the DeepSeek-R1 client
    endpoint = os.getenv("AZURE_INFERENCE_ENDPOINT")
    key = os.getenv("AZURE_INFERENCE_KEY")
    model_name = os.getenv("MODEL_NAME", "DeepSeek-R1")
    
    # Initialize direct chat client
    deepseek_client = ChatCompletionsClient(
        endpoint=endpoint, # type: ignore
        credential=AzureKeyCredential(key), # type: ignore
        headers={"x-ms-model-mesh-model-name": model_name}  # Add the model name in the header
    )
    print(f"✅ DeepSeek-R1 client initialized | Model: {model_name}")
    
    # Initialize Tavily client - you need to set this in your .env file or directly here
    TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "tvly-dev-YOUR_API_KEY_HERE")
    # TAVILY_API_KEY = input("Please enter your Tavily API key (starts with tvly-): ")
    if TAVILY_API_KEY and TAVILY_API_KEY.startswith("tvly-"):
        tavily_client = tavily.TavilyClient(TAVILY_API_KEY)
        print("✅ Tavily client initialized")
    else:
        tavily_client = None
        print("⚠️ Invalid Tavily API key, web search will not be available")
    
except Exception as e:
    print(f"❌ Setup error: {e}")
    deepseek_client = None
    tavily_client = None

# Function to search for FinOps documentation using Tavily
def search_finops_docs_with_tavily(query, max_results=5):
    """Search for FinOps documentation using Tavily search API"""
    if not tavily_client:
        return {"error": "Tavily client not initialized"}
    
    # Focus search on Microsoft FinOps documentation
    search_query = f"{query} Microsoft Azure FinOps hub documentation"
    
    try:
        # Execute the search
        response = tavily_client.search(
            query=search_query,
            search_depth="advanced",  # Use advanced for more comprehensive results
            max_results=max_results,
            include_answer="advanced",  # Get a summarized answer
            include_domains=["microsoft.com", "azure.com", "learn.microsoft.com"]  # Focus on Microsoft docs
        )
        
        # Format the results in a structured way
        formatted_text = "## Microsoft FinOps Documentation Search Results\n\n"
        
        # Add the Tavily-generated answer if available
        if "answer" in response and response["answer"]:
            formatted_text += f"### Summary\n{response['answer']}\n\n"
        
        # Add individual search results
        if "results" in response:
            for i, result in enumerate(response["results"], 1):
                formatted_text += f"### {i}. {result.get('title', 'Untitled')}\n"
                formatted_text += f"Source: {result.get('url', 'No URL')}\n"
                formatted_text += f"{result.get('content', 'No content available')}\n\n"
        
        return {
            "status": "success",
            "formatted_text": formatted_text,
            "raw_results": response["results"] if "results" in response else [],
            "urls": [r.get("url") for r in response.get("results", []) if "url" in r],
            "answer": response.get("answer", "")
        }
    
    except Exception as e:
        print(f"❌ Tavily search error: {str(e)}")
        return {
            "status": "error",
            "error": str(e)
        }


# FinOps expert function with Tavily search
def finops_expert_with_tavily(query):
    """Get expert FinOps advice using DeepSeek-R1 and Tavily search"""
    
    if not deepseek_client:
        return "Error: DeepSeek-R1 client not initialized. Please check your configuration."
    
    try:
        print(f"🔍 Searching for FinOps documentation about: {query}")
        
        # Initialize variables before conditional blocks
        context = ""
        urls = []
        
        # Try to get documentation from Tavily search if client is available
        if tavily_client:
            search_result = search_finops_docs_with_tavily(query)
            
            # Prepare context based on search results
            if search_result.get('status') == 'success':
                print("✅ Found relevant documentation from Tavily search")
                context = search_result['formatted_text']
                urls = search_result.get('urls', [])
        
        # Define the finops system prompt
        finops_system_prompt = """You are a Microsoft FinOps toolkit expert with deep knowledge of:
        
        1. FinOps Framework: The operational framework for financial management of cloud resources.
        2. Microsoft Cost Management: How to analyze, track, and allocate cloud spending.
        3. FinOps Hub Implementation: Setup, validation, and troubleshooting.
        4. Data Factory Pipelines: How they ingest and transform cost data.
        5. Power BI Cost Reports: Connection methods and optimization.
        6. VM Cost Optimization: Strategies for right-sizing, reservation, and scheduling VMs.
        
        When answering questions about FinOps hub validation, include these specific steps:
        1. Verify Cost Management exports are successful
        2. Verify Data Factory pipelines are running correctly
        3. Check msexports container for raw data files
        4. Check ingestion container for processed parquet files
        5. Validate Power BI configuration if applicable
        
        For Data Factory pipeline troubleshooting, check:
        - If msexports_ManifestAdded trigger is started
        - Whether all necessary resource providers are registered
        - For specific error codes in pipeline run history
        - For column mapping errors in the ETL pipeline

        When answering questions:
        - Provide clear, step-by-step guidance
        - Include specific Azure portal navigation steps
        - Mention PowerShell or Azure CLI commands where applicable
        - Reference the documentation provided in the context
        - Include both immediate fixes and long-term strategies
        """
        
        # Add the search results as context
        user_message = f"""
        Based on Microsoft's FinOps documentation:
        
        {context} # type: ignore
        
        User query: {query}
        
        Please provide expert guidance on this FinOps toolkit question based on the documentation.
        Include specific, step-by-step instructions and reference the documentation where relevant.
        """
        
        # Get DeepSeek reasoning
        response = deepseek_client.complete(
            messages=[
                SystemMessage(content=finops_system_prompt),
                UserMessage(content=user_message)
            ],
            model=model_name,
            temperature=0.3,
            max_tokens=2048
        )
        
        content = response.choices[0].message.content
        
        # Add references to the content if URLs were found
        if urls:
            content += "\n\n## References\n"
            for i, url in enumerate(urls, 1):
                content += f"{i}. [{url.split('/')[-1].replace('-', ' ').title()}]({url})\n"
        
        return content
        
    except Exception as e:
        return f"Error generating response: {str(e)}"

# Example usage
print("\n---------- FinOps Expert with Tavily Search ----------")
finops_questions = [
    "I have this error message in my finops hub deployment. AccountPropertyCannotBeUpdated?",

]

# Test with the first question
print(f"\n📝 Question: {finops_questions[0]}")
answer = finops_expert_with_tavily(finops_questions[0])
print(f"\n🔍 Answer: {answer}")

# Uncomment to test all questions
# for question in finops_questions:
#     print(f"\n📝 Question: {question}")
#     answer = finops_expert_with_tavily(question)
#     print(f"\n🔍 Answer: {answer}")