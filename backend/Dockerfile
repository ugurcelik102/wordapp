FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt .
COPY app/ app/
COPY scripts/ scripts/

RUN pip install -r requirements.txt

CMD ["python", "app/main.py"]