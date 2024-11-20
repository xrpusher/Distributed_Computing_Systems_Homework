# main.py

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, validator, ValidationError
from app_server import process_number
import json

app = FastAPI()

class NumberInput(BaseModel):
    number: int

    @validator('number')
    def validate_number(cls, v):
        if not isinstance(v, int):
            raise ValueError("Значение 'number' должно быть целым числом.")
        if v < 0:
            raise ValueError("Число должно быть натуральным (больше или равно 0).")
        return v

# Остальной код остается без изменений


@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    errors = exc.errors()
    error_messages = []
    for error in errors:
        field = ' -> '.join(str(loc) for loc in error['loc'])
        message = f"{field}: {error['msg']}"
        error_messages.append(message)
    return JSONResponse(
        status_code=422,
        content={"detail": error_messages}
    )

@app.exception_handler(json.decoder.JSONDecodeError)
async def json_decode_exception_handler(request: Request, exc: json.decoder.JSONDecodeError):
    return JSONResponse(
        status_code=400,
        content={"detail": "Некорректный JSON в теле запроса."}
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

@app.post("/process_number")
async def process_number_endpoint(request: Request):
    try:
        # Получаем JSON из тела запроса
        data = await request.json()
    except json.decoder.JSONDecodeError:
        # Если JSON некорректен
        return JSONResponse(
            status_code=400,
            content={"detail": "Некорректный JSON в теле запроса."}
        )
    try:
        # Валидируем данные с помощью Pydantic
        input_data = NumberInput(**data)
    except ValidationError as ve:
        # Обрабатываем ошибки валидации
        errors = ve.errors()
        error_messages = []
        for error in errors:
            field = ' -> '.join(str(loc) for loc in error['loc'])
            message = f"{field}: {error['msg']}"
            error_messages.append(message)
        return JSONResponse(
            status_code=422,
            content={"detail": error_messages}
        )
    number = input_data.number
    try:
        result = process_number(number)
        return {"result": result}
    except HTTPException as e:
        # Обрабатываем исключения, вызванные бизнес-логикой
        raise e
    except Exception as e:
        # Обрабатываем непредвиденные ошибки
        return JSONResponse(
            status_code=500,
            content={"detail": "Внутренняя ошибка сервера."}
        )
