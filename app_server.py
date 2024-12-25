from fastapi import HTTPException
from database import Database
import logging
import os

# Настройка логирования
logger = logging.getLogger("app_logger")
logger.setLevel(logging.ERROR)
handler = logging.StreamHandler()  # Логирование в stdout
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
if not logger.handlers:
    logger.addHandler(handler)

db = Database()

def process_number(number: int) -> int:
    if db.is_number_processed(number):
        message = f"Исключительная ситуация #1: Число {number} уже поступало ранее."
        logger.error(message)
        raise HTTPException(status_code=400, detail="Число уже поступало ранее.")
    if db.is_number_minus_one_of_processed(number):
        message = f"Исключительная ситуация #2: Число {number} на единицу меньше уже обработанного числа."
        logger.error(message)
        raise HTTPException(status_code=400, detail="Число на единицу меньше уже обработанного числа.")
    db.add_number(number)
    return number + 1
