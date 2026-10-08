# syntax=docker/dockerfile:1
# Image for LiveKit Cloud agents (`lk agent create` / `lk agent deploy`) or any container host.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

RUN useradd --create-home --uid 10001 appuser
WORKDIR /home/appuser/app

COPY pyproject.toml uv.lock* ./
RUN uv sync --no-dev --no-install-project $( [ -f uv.lock ] && echo --locked )

COPY src ./src
RUN chown -R appuser:appuser /home/appuser/app
USER appuser

WORKDIR /home/appuser/app/src
CMD ["uv", "run", "--no-sync", "agent.py", "start"]
