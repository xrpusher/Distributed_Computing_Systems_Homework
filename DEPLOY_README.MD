## Инструкция по сборке и деплою проекта с использованием Docker и Kubernetes

### 1. Подготовка Docker-образа

1. Убедитесь, что у вас в корне проекта находится Dockerfile:

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app/
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

2. Сборка Docker-образа:

```bash
docker build -t your_dockerhub_name/your_app_image:tag .
```

3. Вход в Docker Hub:

```bash
docker login
```

4. Загрузка образа в Docker Hub:

```bash
docker push your_dockerhub_name/your_app_image:tag
```

5. Убедитесь, что в манифесте Kubernetes (fastapi-deployment.yaml) указан тот же образ:

```yaml
containers:
  - name: fastapi-container
    image: your_dockerhub_name/your_app_image:tag
    ...
```

Если уже используете `xrpusher/achiev_2_alisher:v1.0.0`, этот шаг можно пропустить.

---

### 2. Деплой в Kubernetes

1. Создание namespace:

```bash
kubectl apply -f namespace.yaml
```

2. Создание ConfigMap:

```bash
kubectl apply -f configmap.yaml -n ns-37
```

3. Создание Secret:

```bash
kubectl apply -f secret.yaml -n ns-37
```

4. Деплой PostgreSQL (Deployment + Service + PVC):

```bash
kubectl apply -f postgres-deployment.yaml -n ns-37
```

5. Деплой FastAPI (Deployment + Service):

```bash
kubectl apply -f fastapi-deployment.yaml -n ns-37
```

6. Деплой Ingress:

```bash
kubectl apply -f ingress.yaml -n ns-37
```

---

### 3. Проверка работы приложения

1. Убедитесь, что все поды находятся в статусе “Running” или “Ready”:

```bash
kubectl get pods -n ns-37
```

2. Посмотрите логи при необходимости:

```bash
kubectl logs <pod_name> -n ns-37
```

3. Узнайте внешний IP Ingress-контроллера:

```bash
kubectl get svc -n haproxy-controller
```

4. Пропишите в `/etc/hosts` следующую строку (на локальной машине):

```plaintext
<IP_INGRESS_CONTROLLER>   ns-37.a.ru
```

Пример:

```plaintext
10.98.8.45   ns-37.a.ru
```

5. Проверьте приложение запросом:

```bash
curl -X POST "http://ns-37.a.ru/process_number" \
     -H "Content-Type: application/json" \
     -d '{"number": 5}'
```

Ожидаемый ответ: `{"result":6}` или информация об ошибке, если число уже было обработано.

---

### 4. Локальный запуск через docker-compose

1. Убедитесь, что у вас есть `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:17
    container_name: postgres_db
    environment:
      POSTGRES_DB: mydatabase
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
    ports:
      - "5434:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myuser -d mydatabase"]
      interval: 5s
      timeout: 5s
      retries: 5

  fastapi:
    image: xrpusher/achiev_2_alisher:v1.0.0
    container_name: fastapi_app
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "8000:8000"
    environment:
      DB_NAME: mydatabase
      DB_USER: myuser
      DB_PASSWORD: mypassword
      DB_HOST: db
      DB_PORT: 5432
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
    restart: always

volumes:
  db_data:
```

2. Запустите проект локально:

```bash
docker-compose up -d
```

3. Проверьте логи:

```bash
docker-compose logs db
docker-compose logs fastapi
```

4. Отправьте тестовый запрос:

```bash
curl -X POST "http://localhost:8000/process_number" \
     -H "Content-Type: application/json" \
     -d '{"number": 5}'
```

Ожидаемый результат: `{"result":6}`.

---

### 5. Заключительные замечания

- Порт `5434` (локально) и `5432` (в Kubernetes) — это нормально, так как в `docker-compose` вы делаете `"5434:5432"`, чтобы избежать конфликтов.
- Ingress требует корректной настройки Ingress Controller. Убедитесь, что `ingressClassName: haproxy` соответствует контроллеру.
- В `/etc/hosts` домен `ns-37.a.ru` должен указывать на IP Ingress Controller.

Следуя этой инструкции, вы сможете развернуть инфраструктуру (PostgreSQL + FastAPI + Ingress) и протестировать приложение по адресу `http://ns-37.a.ru/process_number`.
