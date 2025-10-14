from fastapi import FastAPI

app = FastAPI(title="Vision360 API")

@app.get("/health")
def health():
    return {"status": "ok"}
