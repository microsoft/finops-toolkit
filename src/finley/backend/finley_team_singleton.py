"""
finley_team_singleton.py

Singleton pattern for initializing and accessing the FinleyTeam instance.
Used throughout the FastAPI app to ensure only one team is created.
"""

from typing import Optional
from finley_team_orchestration import FinleyTeam

_team_instance: Optional[FinleyTeam] = None


def get_finley_team() -> FinleyTeam:
    """
    Retrieves the shared FinleyTeam instance. Initializes it on first access.

    Returns:
        FinleyTeam: A singleton instance of the FinleyTeam class.

    Raises:
        RuntimeError: If team initialization fails.
    """
    global _team_instance

    if _team_instance is None:
        try:
            _team_instance = FinleyTeam()
        except Exception as e:
            raise RuntimeError(f"Failed to initialize FinleyTeam: {e}") from e

    return _team_instance
