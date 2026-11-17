import os
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class Config:
    SQLALCHEMY_DATABASE_URI = "sqlite:///" + \
        os.path.join(BASE_DIR, "database", "assistencia.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "troque-isso-em-producao")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "troque-essa-chave-tambem")
