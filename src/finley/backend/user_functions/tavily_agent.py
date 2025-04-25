import os
import json
from dotenv import load_dotenv
from pathlib import Path

# Azure + DeepSeek
from azure.ai.inference import ChatCompletionsClient
from azure.ai.inference.models import SystemMessage, UserMessage
from azure.core.credentials import AzureKeyCredential

# Load environment variables
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

# Setup DeepSeek client
endpoint = os.getenv("AZURE_INFERENCE_ENDPOINT")
key = os.getenv("AZURE_INFERENCE_KEY")
model_name = os.getenv("MODEL_NAME", "DeepSeek-R1")

deepseek_client = ChatCompletionsClient(
    endpoint=endpoint,
    credential=AzureKeyCredential(key),
    headers={"x-ms-model-mesh-model-name": model_name},
)

# Setup Tavily
try:
    import tavily
except ImportError:
    import pip

    pip.main(["install", "tavily-python"])
    import tavily

TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")
tavily_client = tavily.TavilyClient(TAVILY_API_KEY) if TAVILY_API_KEY else None


def finops_expert_with_tavily(query: str) -> str:
    """
    Uses Tavily to search for FinOps documentation, and DeepSeek to generate a smart answer.
    """
    if not deepseek_client:
        return "❌ DeepSeek client not initialized."

    if not tavily_client:
        return "❌ Tavily client not initialized."

    try:
        search_query = f"{query}"

        response = tavily_client.search(
            query=search_query,
            search_depth="advanced",
            max_results=1,
            include_answer="advanced",
            # include_domains=["learn.microsoft.com", "finops.org", "microsoft.com"],
            include_domains=["finops.org","focus.finops.org","x.finops.org"],
        )

        docs_summary = response.get("answer", "")
        docs_results = response.get("results", [])

        context = f"### Summary from Docs\n{docs_summary}\n\n"

        for i, result in enumerate(docs_results, 1):
            context += f"### {i}. {result.get('title', 'Untitled')}\n"
            context += f"URL: {result.get('url')}\n"
            context += f"{result.get('content', 'No content available')}\n\n"

        # DeepSeek prompt
        system_prompt = """
        Keep the exact wording of the documentation. Just make sure the links referenced in the answer are clickable and exist.
        Provide a nice and pretty markdown answer to the user query.
        """

        user_prompt = f"""
        Context from Tavily search:

        {context}

        User query:
        {query}
        """

        response = deepseek_client.complete(
            model=model_name,
            temperature=0.1,
            max_tokens=2048,
            messages=[
                SystemMessage(content=system_prompt),
                UserMessage(content=user_prompt),
            ],
        )

        result_text = response.choices[0].message.content

        # Add references at the bottom
        urls = [r["url"] for r in docs_results if "url" in r]
        if urls:
            result_text += "\n### References\n"
            for i, url in enumerate(urls, 1):
                result_text += f"{i}. [{url}]({url})\n"

        return result_text

    except Exception as e:
        return f"❌ Error generating answer: {str(e)}"
