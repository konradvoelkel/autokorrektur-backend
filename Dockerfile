FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

# Dependencies first, so a code change doesn't invalidate the layer.
COPY pyproject.toml uv.lock* README.md ./
RUN uv sync --frozen --no-dev

COPY *.py ./
COPY templates ./templates

EXPOSE 8000

RUN adduser --disabled-password --no-create-home appuser
USER appuser

CMD ["uv", "run", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
