from fastapi import FastAPI
from .reservations import router as reservations_router
from .guidance import router as guidance_router

app = FastAPI(title="Vision360 API")

@app.get("/health")
def health():
    return {"status": "ok"}

# Reservations routes (stub v1)
app.include_router(reservations_router, prefix="/api", tags=["reservations"])
app.include_router(guidance_router, prefix="/api", tags=["guidance"])
