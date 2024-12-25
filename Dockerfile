FROM python:3.10-slim

WORKDIR /app

# Установить системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-openbsd nano && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Установить зависимости Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Скопировать исходный код
COPY . /app/

# Установить переменные окружения
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Открыть порт
EXPOSE 8000

# Команда для запуска приложения
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
