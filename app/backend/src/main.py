from fastapi import FastAPI

app = FastAPI(title="App API")


@app.get("/health")
def health():
    return {"status": "ok"}
