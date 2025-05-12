from fastapi import APIRouter, Request, Query
from fastapi.responses import StreamingResponse, JSONResponse
from models.request_models import UserInput
from services.agent_runner import stream_response
import uuid

router = APIRouter()


@router.get("/api/ask-stream")
async def ask_stream(prompt: str = Query(...), sessionId: str = Query(None)):
    session_id = sessionId or str(uuid.uuid4())
    return StreamingResponse(stream_response(prompt, session_id), media_type="text/event-stream")



# @router.post("/api/ask")
# async def ask_post(input: UserInput, request: Request):
#     session_id = request.headers.get("x-session-id", str(uuid.uuid4()))
#     return StreamingResponse(stream_response(input.message, session_id), media_type="text/event-stream")

@router.get("/health")
async def health():
    return JSONResponse({"status": "healthy"})


@router.get("/")
async def root():
    return {"message": "Finley backend is running"}
