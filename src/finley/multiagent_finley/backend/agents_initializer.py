import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from semantic_kernel.agents import AgentGroupChat, AzureAIAgent, AzureAIAgentSettings
from semantic_kernel.agents.strategies import TerminationStrategy
from user_functions.adx_query import ADXFunctions
from user_functions.resource_graph import ARGFunctions

load_dotenv()

# Load prompts
def load_prompt(filepath: str) -> str:
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

FINLEY_PROMPT = load_prompt("prompts/finley_teamleader_agent_prompt.txt")
ADX_PROMPT = load_prompt("prompts/adx_query_agent_prompt.txt")
ARG_PROMPT = load_prompt("prompts/arg_query_agent_prompt.txt")

TEAM_LEADER_NAME = "Finley"
ADX_QUERY_AGENT_NAME = "ADXQueryAgent"
ARG_QUERY_AGENT_NAME = "ARGQueryAgent"

adx_tool = {
    "type": "function",
    "function": {
        "name": "query_adx_database",
        "description": "Query Azure Data Explorer",
        "parameters": {
            "type": "object",
            "properties": {
                "cluster_url": {"type": "string"},
                "database": {"type": "string"},
                "kql_query": {"type": "string"},
            },
            "required": ["cluster_url", "database", "kql_query"],
        },
    }
}

arg_tool = {
    "type": "function",
    "function": {
        "name": "query_arg",
        "description": "Query Azure Resource Graph",
        "parameters": {
            "type": "object",
            "properties": {
                "arg_query": {"type": "string"}
            },
            "required": ["arg_query"],
        },
    }
}

class QueryCompletionStrategy(TerminationStrategy):
    async def should_agent_terminate(self, _agent, history):
        if not history:
            return False
        return "query complete" in history[-1].content.lower()

async def create_agent(client, name, model, instructions, tools, plugins):
    definition = await client.agents.create_agent(
        model=model,
        name=name,
        instructions=instructions,
        tools=tools
    )
    return AzureAIAgent(client=client, definition=definition, plugins=plugins)

async def initialize_agents():
    ai_agent_settings = AzureAIAgentSettings.create()
    connection_string = os.getenv("AZURE_AI_AGENT_CONNECTION_STRING")
    creds = DefaultAzureCredential()

    # No await here – returns AIProjectClient directly
    client = AzureAIAgent.create_client(
        credential=creds,
        connection_string=connection_string
    )

    finley_agent = await create_agent(
        client, TEAM_LEADER_NAME,
        ai_agent_settings.model_deployment_name,
        FINLEY_PROMPT,
        tools=[],
        plugins=[]
    )

    adx_agent = await create_agent(
        client, ADX_QUERY_AGENT_NAME,
        ai_agent_settings.model_deployment_name,
        ADX_PROMPT,
        tools=[adx_tool],
        plugins=[ADXFunctions()]
    )

    arg_agent = await create_agent(
        client, ARG_QUERY_AGENT_NAME,
        ai_agent_settings.model_deployment_name,
        ARG_PROMPT,
        tools=[arg_tool],
        plugins=[ARGFunctions()]
    )

    return client, [finley_agent, adx_agent, arg_agent]

async def create_chat(agents):
    finley_agent = next(a for a in agents if a.name == "Finley")
    arg_agent = next(a for a in agents if a.name == "ARGQueryAgent")
    adx_agent = next(a for a in agents if a.name == "ADXQueryAgent")

    return AgentGroupChat(
        agents=agents,
        termination_strategy=QueryCompletionStrategy(
            agents=[finley_agent, arg_agent, adx_agent],
            maximum_iterations=10
        )
    )