from sqlalchemy.engine import Engine
from sqlalchemy import event
import sqlite3
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt

db = SQLAlchemy()
cors = CORS()
jwt = JWTManager()
bcrypt = Bcrypt()


@event.listens_for(Engine, "connect")
def ativar_foreign_keys(dbapi_connection, connection_record):
    if isinstance(dbapi_connection, sqlite3.Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys = ON")
        cursor.close()
