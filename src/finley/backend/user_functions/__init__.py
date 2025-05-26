# user_functions/__init__.py

from typing import Set, Callable
# from user_functions.vector_search import run_vector_search
# from user_functions.search_kql_docs import search_kql_docs_vector_only
from user_functions.query_adx_strict import query_adx_database
# from user_functions.query_adx_strict_cag_1 import query_adx_database
# from user_functions.search_web_docs import search_web_docs
from user_functions.vector_search_enhanced import run_vector_search

user_functions: Set[Callable] = {
    query_adx_database,
    run_vector_search,
    # search_web_docs,
}
