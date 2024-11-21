import os
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
        data = await request.json()
    except json.decoder.JSONDecodeError:
        return JSONResponse(
            status_code=400,
            content={"detail": "Некорректный JSON в теле запроса."}
        )
    try:
        input_data = NumberInput(**data)
    except ValidationError as ve:
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
        raise e
    except Exception as e:
        # Логируем исключение
        traceback_str = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
        print(f"An error occurred: {traceback_str}")
        return JSONResponse(
            status_code=500,
            content={"detail": "Внутренняя ошибка сервера."}
        )