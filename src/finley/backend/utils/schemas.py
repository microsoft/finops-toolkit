from typing import List, Optional, Dict, Union
from pydantic import BaseModel, Field

class ADXPreviewRow(BaseModel):
    BillingCurrency: str
    row: Dict[str, Union[str, float, int]] = Field(
        ..., description="Dynamic columns from the ADX query result"
    )

class ADXQueryResult(BaseModel):
    summary: str
    preview: List[ADXPreviewRow]

class SourceCitation(BaseModel):
    title: str
    filename: str
    url: Optional[str] = None  # Optional link to the markdown file

class FocusAgentOutput(BaseModel):
    summary: str
    explanation: str
    sources: List[SourceCitation]