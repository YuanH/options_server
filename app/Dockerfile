# app/Dockerfile

# Use official uv image with Python 3.14
FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim

WORKDIR /app

# Copy dependency files first to leverage Docker layer caching
COPY pyproject.toml uv.lock /app/

# Install dependencies using uv
# --no-dev excludes development dependencies
# --frozen ensures the lockfile is not updated
RUN uv sync --frozen --no-dev

# Copy application code
COPY . /app/

# Expose the application port
EXPOSE 5000

# Use uv to run the application, which automatically uses the project's virtual environment
CMD ["uv", "run", "gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
