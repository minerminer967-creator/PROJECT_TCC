from flask import Blueprint, request, jsonify
from extensions import db, bcrypt
from models import Usuario
from flask_jwt_extended import create_access_token

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/registrar', methods=['POST'])
def registrar():
    data = request.get_json()

    if not data.get('nome') or not data.get('email') or not data.get('senha'):
        return jsonify({"erro": "nome. email e senha são obrigatórios"}), 400

    if Usuario.query.filter_by(email=data['email']).first():
        return jsonify({"erro": "Email já cadastrado"}), 400

    senha_hash = bcrypt.generate_password_hash(data['senha']).decode('utf-8')

    usuario = Usuario(
        nome=data['nome'],
        email=data['email'],
        senha=senha_hash,
        perfil=data.get('perfil', 'funcionario')
    )

    db.session.add(usuario)
    db.session.commit()

    return jsonify({"id": usuario.id, "nome": usuario.nome, "perfil": usuario.perfil}), 201


@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json()

    if not data.get('email') or not data.get('senha'):
        return jsonify({"erro": "email e senha são obrigatórios"}), 400

    usuario = Usuario.query.filter_by(email=data['email']).first()

    if not usuario or not bcrypt.check_password_hash(usuario.senha, data['senha']):
        return jsonify({"erro": "email ou senha inválidos"}), 401

    token = create_access_token(identity=str(usuario.id), additional_claims={
                                "perfil": usuario.perfil})

    return jsonify({"access_token": token, "nome": usuario.nome, "perfil": usuario.perfil}), 200
