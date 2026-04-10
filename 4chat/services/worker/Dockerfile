FROM python:3.11.15
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY common/ /app/services/common/
