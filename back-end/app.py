from flask import Flask
from flask_cors import CORS
from extensions import db
from config import config


def criacao_app():
    app = Flask(__name__)
    app.config.from_object(config)

    db.init_app(app)
    CORS(app)

    from routes.clientes import clientes_bp
    from routes.equipamentos import equipamento_bp
    from routes.ordens_servicos import os_bp
    from routes.pecas import pecas_bp

    app.register_blueprint(pecas_bp, url_prefix='/api/pecas')
    app.register_blueprint(clientes_bp, url_prefix='/api/clientes')
    app.register_blueprint(equipamento_bp, url_prefix='/api/equipamentos')
    app.register_blueprint(os_bp, url_prefix='/api/ordens-servicos')

    with app.app_context():
        db.create_all()

    return app


if __name__ == "__main__":
    app = criacao_app()
    app.run(debug=True, port=5000)
