import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL", "sqlite:///assistencia.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "troque-isso-em-producao")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "troque-essa-chave-tambem")
