# STAGE 1: Build the applicatio
FROM python:3.11-slim AS builder
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
# Create a virtual environment
RUN python -m venv /opt/venv 
# Activate the virtual environment
ENV PATH="/opt/venv/bin:$PATH" 
COPY requirements.txt .
RUN pip install -r requirements.txt


# STAGE 2: Run the application
FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PATH="/opt/venv/bin:$PATH"
# Create a non-root user with a specific UID for better security
RUN useradd --create-home --uid 1000 appuser 
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/ 
COPY migrations/ ./migrations/
COPY alembic.ini run.py ./ 
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh 
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && chown appuser:appuser /app
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request, sys; \
import urllib.error; \
sys.exit(0) if urllib.request.urlopen('http://localhost:5000/api/health', timeout=4).status == 200 else sys.exit(1)" || exit 1
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["gunicorn", "--workers", "3", "--bind", "0.0.0.0:5000", "run:app"] 