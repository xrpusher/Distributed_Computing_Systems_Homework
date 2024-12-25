# database.py

import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()  # Загружает переменные из .env

class Database:
    def __init__(self):
        self.conn = psycopg2.connect(
            dbname=os.getenv('DB_NAME', 'mydatabase'),
            user=os.getenv('DB_USER', 'myuser'),
            password=os.getenv('DB_PASSWORD', 'mypassword'),
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432')  # Убедитесь, что порт правильный
        )
        self.create_table()

    def create_table(self):
        with self.conn.cursor() as cursor:
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS numbers (
                    number INTEGER PRIMARY KEY
                )
            ''')
            self.conn.commit()

    def is_number_processed(self, number: int) -> bool:
        with self.conn.cursor() as cursor:
            cursor.execute('SELECT 1 FROM numbers WHERE number = %s', (number,))
            return cursor.fetchone() is not None

    def is_number_minus_one_of_processed(self, number: int) -> bool:
        with self.conn.cursor() as cursor:
            # Проверяем, есть ли число, которое равно number + 1
            cursor.execute('SELECT 1 FROM numbers WHERE number = %s', (number + 1,))
            return cursor.fetchone() is not None

    def add_number(self, number: int):
        with self.conn.cursor() as cursor:
            cursor.execute('INSERT INTO numbers (number) VALUES (%s) ON CONFLICT DO NOTHING', (number,))
            self.conn.commit()
