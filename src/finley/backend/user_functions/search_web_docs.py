from user_functions.tavily_agent import finops_expert_with_tavily

def search_web_docs(query: str):
    """
    Tool to search Microsoft FinOps documentation using Tavily + DeepSeek.
    """
    result = finops_expert_with_tavily(query)
    return {
        "summary": "Documentation answer retrieved using Tavily and DeepSeek.",
        "preview": [result[:300]],
        "content": result
    }
