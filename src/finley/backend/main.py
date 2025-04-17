from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from contextlib import asynccontextmanager
from finley_team_singleton import get_finley_team
import json
import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        get_finley_team()
        print("✅ FinleyTeam initialized at startup")
    except Exception as e:
        print(f"❌ Failed to initialize FinleyTeam: {e}")
    yield
    print("👋 FinleyTeam app shutting down...")

# ✅ Only one app instance with both CORS and lifespan
app = FastAPI(lifespan=lifespan)

# ✅ Apply CORS middleware to the correct app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/api/ask-stream")
async def ask_stream(request: Request):
    prompt = request.query_params.get("prompt")
    if not prompt:
        return {"error": "Missing prompt"}

    print(f"✅ Prompt received: {prompt}")
    finley = get_finley_team()
    def next_chunk(gen):
        try:
            return next(gen)
        except StopIteration:
            return None
        
    async def event_stream():
        loop = asyncio.get_event_loop()
        generator = finley.process_request(prompt)

        while True:
            chunk = await loop.run_in_executor(None, next_chunk, generator)
            if chunk is None:
                break

            try:
                parsed = json.loads(chunk)
                yield f"data: {chunk}\n\n"
            except Exception:
                payload = {
                    "role": "agent",
                    "agent": "Finley",
                    "content": chunk
                }
                yield f"data: {json.dumps(payload)}\n\n"

        # ✅ End-of-stream signal
        yield f"data: {json.dumps({'content': '[DONE]'})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")