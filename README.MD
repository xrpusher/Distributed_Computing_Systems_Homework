# Диаграммы

Диаграммы компонентов и последовательностей в файлах  Component_Diagram.png и Sequence_Diagram.png.

# Создание окружения

python -m venv venv  

source venv/bin/activate

# Запуск сервера

python -m uvicorn main:app --host 0.0.0.0 --port 8000

# Отправка тестовых запросов

## 1

curl -X POST "http://0.0.0.0:8000/process_number" \
     -H "Content-Type: application/json" \
     -d '{"number": 5}'

## 1 A

{"result":6}

## 2 Исключительная ситуация #1 (число уже поступало ранее)

curl -X POST "http://0.0.0.0:8000/process_number" \
     -H "Content-Type: application/json" \
     -d '{"number": 5}'

## 2 A

{"detail":"Число уже поступало ранее."}

## 3 Исключительная ситуация #2 (число на единицу меньше максимального)

curl -X POST "http://0.0.0.0:8000/process_number" \
     -H "Content-Type: application/json" \
     -d '{"number": 4}'

## 3 A 

{"detail":"Число на единицу меньше уже обработанного числа."}