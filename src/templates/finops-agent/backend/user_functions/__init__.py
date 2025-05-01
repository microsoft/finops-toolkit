# user_functions/__init__.py

from typing import Set, Callable
# from .resource_graph import query_resource_graph
from user_functions.vector_search import run_vector_search
# from finley.backend.user_functions.search_kql_docs_old import search_kql_docs_hybrid
from user_functions.search_kql_docs import search_kql_docs_vector_only
from user_functions.search_web_docs import search_web_docs
from user_functions.finley_functions import (
    query_adx_database,
    run_vector_search2,
    
    # query_resource_graph,
)
user_functions: Set[Callable] = {
    # query_resource_graph,
    query_adx_database,
    run_vector_search,
    run_vector_search2,
    # search_kql_docs_hybrid,
    search_kql_docs_vector_only,
    search_web_docs
}
