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