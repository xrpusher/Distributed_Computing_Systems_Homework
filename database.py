# database.py

import sqlite3
import os

class Database:
    def __init__(self):
        self.db_path = 'numbers.db'
        self.conn = sqlite3.connect(self.db_path)
        self.create_table()

    def create_table(self):
        cursor = self.conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS numbers (
                number INTEGER PRIMARY KEY
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS max_number (
                id INTEGER PRIMARY KEY,
                number INTEGER
            )
        ''')
        self.conn.commit()

    def is_number_processed(self, number: int) -> bool:
        cursor = self.conn.cursor()
        cursor.execute('SELECT 1 FROM numbers WHERE number = ?', (number,))
        return cursor.fetchone() is not None

    def is_number_minus_one_of_max(self, number: int) -> bool:
        cursor = self.conn.cursor()
        cursor.execute('SELECT number FROM max_number WHERE id = 1')
        row = cursor.fetchone()
        if row:
            max_number = row[0]
            return number == max_number - 1
        return False

    def add_number(self, number: int):
        cursor = self.conn.cursor()
        cursor.execute('INSERT OR IGNORE INTO numbers (number) VALUES (?)', (number,))
        cursor.execute('SELECT number FROM max_number WHERE id = 1')
        row = cursor.fetchone()
        if row:
            current_max = row[0]
            if number > current_max:
                cursor.execute('UPDATE max_number SET number = ? WHERE id = 1', (number,))
        else:
            cursor.execute('INSERT INTO max_number (id, number) VALUES (1, ?)', (number,))
        self.conn.commit()
