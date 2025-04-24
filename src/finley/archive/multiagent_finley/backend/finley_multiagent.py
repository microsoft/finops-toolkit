import json
from user_functions.adx_query import ADXFunctions
from user_functions.resource_graph import ARGFunctions

async def handle_function_call(function_call):
    print(f"📞 Function call: {function_call.function_name} | Args: {function_call.arguments}")

    if function_call.function_name == "query_adx_database":
        args = function_call.arguments
        return ADXFunctions().query_adx_database(
            cluster_url=args["cluster_url"],
            database=args["database"],
            kql_query=args["kql_query"]
        )

    elif function_call.function_name == "query_arg":
        args = function_call.arguments
        return ARGFunctions().query_resource_graph(query=args["arg_query"])

    return json.dumps({"error": f"Unknown function {function_call.function_name}"})
