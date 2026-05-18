FROM python:3.12

WORKDIR /src

RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY ./src/ /src/

# venv от uv
ENV PATH="/src/.venv/bin:$PATH"

CMD bash -c "python3 migrate.py upgrade && gunicorn main:app --workers ${NUM_WORKERS} --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:${SERVICE_PORT} --forwarded-allow-ips='*'"
