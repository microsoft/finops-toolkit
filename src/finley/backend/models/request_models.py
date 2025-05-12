from pydantic import BaseModel

class UserInput(BaseModel):
    """
    Defines the expected structure of user input for POST requests.
    """
    message: str
