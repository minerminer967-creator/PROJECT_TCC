from flask import Blueprint, request, jsonify
from extensions import db, bcrypt
from models import Usuario
from sqlalchemy.exc import IntegrityError                      # NOVO
from flask_jwt_extended import (                               # NOVO
    create_access_token, verify_jwt_in_request, get_jwt
)

auth_bp = Blueprint('auth', __name__)

# NOVO: mesmos do CHECK do schema
PERFIS_VALIDOS = {'admin', 'tecnico', 'funcionario'}


@auth_bp.route('/registrar', methods=['POST'])
def registrar():
    data = request.get_json()

    if not data.get('nome') or not data.get('email') or not data.get('senha'):
        return jsonify({"erro": "nome, email e senha são obrigatórios"}), 400

    # NOVO: se já existe usuário, só admin cadastra outro
    primeiro_usuario = Usuario.query.count() == 0
    if not primeiro_usuario:
        verify_jwt_in_request()
        if get_jwt().get("perfil") != "admin":
            return jsonify({"erro": "somente admin cadastra usuários"}), 403

    # NOVO: o primeiro usuário é sempre admin
    perfil = 'admin' if primeiro_usuario else data.get('perfil', 'funcionario')
    if perfil not in PERFIS_VALIDOS:
        return jsonify({"erro": f"perfil inválido. Use: {sorted(PERFIS_VALIDOS)}"}), 400

    if Usuario.query.filter_by(email=data['email']).first():
        return jsonify({"erro": "email já cadastrado"}), 409

    senha_hash = bcrypt.generate_password_hash(data['senha']).decode('utf-8')

    usuario = Usuario(
        nome=data['nome'],
        email=data['email'],
        senha=senha_hash,
        perfil=perfil
    )

    db.session.add(usuario)
    try:                                                       # NOVO
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "email já cadastrado"}), 409

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
