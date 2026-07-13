FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt .
COPY app/ app/
COPY scripts/ scripts/

RUN pip install -r requirements.txt

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]