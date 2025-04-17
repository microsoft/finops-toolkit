                             ┌────────────────────────────┐
                             │        FastAPI App         │
                             │  with @asynccontextmanager │
                             └────────────┬───────────────┘
                                          │
                      App starts          │
                     ─────────────────────▼─────────────────────
                    ✅ `lifespan()` hook is triggered (once)     
                   │                                            │
                   │   ┌────────────────────────────────────┐   │
                   │   │ get_finley_team()                  │   │
                   │   │ ┌──────────────────────────────┐   │   │
                   │   │ │ if _team_instance is None:   │   │   │
                   │   │ │    _team_instance = FinleyTeam() │   │
                   │   │ └──────────────────────────────┘   │   │
                   │   └────────────────────────────────────┘   │
                   └────────────────────────────────────────────┘
                                          │
                                          ▼
                  ┌────────────────────────────────────────┐
                  │    `/api/ask-stream` route handler     │
                  │         calls `get_finley_team()`      │
                  │    → Reuses the already-created team   │
                  └────────────────────────────────────────┘
                                          │
                                          ▼
                   ┌───────────────────────────────────────┐
                   │ Our agent system processes request    │
                   │ with registered tools, runs, threads  │
                   └───────────────────────────────────────┘
