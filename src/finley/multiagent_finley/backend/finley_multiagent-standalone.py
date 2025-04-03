import asyncio
import os
import json
from dotenv import load_dotenv
from azure.identity.aio import DefaultAzureCredential
from semantic_kernel.agents import AgentGroupChat, AzureAIAgent, AzureAIAgentSettings
from semantic_kernel.agents.strategies import TerminationStrategy, KernelFunctionSelectionStrategy
from semantic_kernel.contents import AuthorRole
from semantic_kernel.contents.function_call_content import FunctionCallContent
from user_functions.adx_query import ADXFunctions
from user_functions.resource_graph import ARGFunctions
from utils.format_output import format_markdown_table, save_csv
from utils.json_extract import extract_json_from_text



load_dotenv()

def load_prompt(filepath: str) -> str:
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

# Configurations
TEAM_LEADER_NAME = "Finley"
ADX_QUERY_AGENT_NAME = "ADXQueryAgent"
ARG_QUERY_AGENT_NAME = "ARGQueryAgent"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "outputs")
os.makedirs(OUTPUT_DIR, exist_ok=True)

FINLEY_PROMPT = load_prompt("prompts/finley_teamleader_agent_prompt.txt")
ADX_PROMPT = load_prompt("prompts/adx_query_agent_prompt.txt")
ARG_PROMPT = load_prompt("prompts/arg_query_agent_prompt.txt")

# Tool definitions
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

# Function call handlers
async def handle_function_call(function_call):
    print(f"📞 Function call: {function_call.function_name} | Args: {function_call.arguments}")

    if function_call.function_name == "query_adx_database":
        args = function_call.arguments
        adx_instance = ADXFunctions()
        return adx_instance.query_adx_database(
            cluster_url=args["cluster_url"],
            database=args["database"],
            kql_query=args["kql_query"]
        )
    
    elif function_call.function_name == "query_arg":
        args = function_call.arguments
        arg_instance = ARGFunctions()
        return arg_instance.query_resource_graph(
            query=args["arg_query"]
        )

    return json.dumps({"error": f"Unknown function {function_call.function_name}"})

# Termination strategy
class QueryCompletionStrategy(TerminationStrategy):
    async def should_agent_terminate(self, _agent, history):
        if not history:
            return False
        return "query complete" in history[-1].content.lower()



# Agent creation
async def create_agent(client, name, model, instructions, tools, plugins):
    definition = await client.agents.create_agent(
        model=model,
        name=name,
        instructions=instructions,
        tools=tools
    )
    return AzureAIAgent(client=client, definition=definition, plugins=plugins)

async def main():
    ai_agent_settings = AzureAIAgentSettings.create()
    connection_string = os.getenv("AZURE_AI_AGENT_CONNECTION_STRING")

    async with DefaultAzureCredential() as creds:
        async with AzureAIAgent.create_client(
            credential=creds, 
            connection_string=connection_string
        ) as client:
            # Create agents
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

            # Setup Group Chat
            chat = AgentGroupChat(
                agents=[finley_agent, adx_agent, arg_agent],
                termination_strategy=QueryCompletionStrategy(
                    agents=[adx_agent, arg_agent],
                    maximum_iterations=10
                )  
                )

            print("✅ Multi-agent system initialized successfully.")

            while True:
                user_input = input("💬 Enter your request ('exit' to quit): ")
                if user_input.lower() in ["exit", "quit"]:
                    break

                await chat.add_chat_message(message=user_input)
                print(f"🧑‍💻 User: {user_input}")

                async for content in chat.invoke():
                    print(f"\n📥 {content.role} - {content.name or '*'}:\n{content.content}")

                    if isinstance(content, FunctionCallContent):
                        result = await handle_function_call(content)
                        await chat.add_chat_message(
                            message=result,
                            role=AuthorRole.TOOL,
                            name=content.function_name
                        )

                    if "query complete" in content.content.lower():
                        parsed_data = extract_json_from_text(content.content)
                        if parsed_data:
                            summary = parsed_data.get("summary", "Query Results")
                            preview = parsed_data.get("preview", [])
                            markdown_output = format_markdown_table(summary, preview)

                            agent_output_md = os.path.join(OUTPUT_DIR, f"{content.name}-output.md")
                            agent_output_csv = os.path.join(OUTPUT_DIR, f"{content.name}-output.csv")

                            with open(agent_output_md, "w", encoding="utf-8") as md_file:
                                md_file.write(markdown_output)
                            save_csv(preview, agent_output_csv)

                            print(f"✅ Output files saved:\n - Markdown: {agent_output_md}\n - CSV: {agent_output_csv}")

                await chat.reset()

            # Cleanup Agents
            await client.agents.delete_agent(finley_agent.id)
            await client.agents.delete_agent(adx_agent.id)
            await client.agents.delete_agent(arg_agent.id)

if __name__ == "__main__":
    asyncio.run(main())
