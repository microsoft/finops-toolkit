# user_functions/__init__.py

from typing import Set, Callable
# from .resource_graph import query_resource_graph
from .adx_queryaif import query_adx_database

user_functions: Set[Callable] = {
    # query_resource_graph,
    query_adx_database

}
