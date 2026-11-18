from flask import Blueprint, jsonify, request
from extensions import db
from models import Peca
from sqlalchemy.exc import IntegrityError    # NOVO
from flask_jwt_extended import jwt_required  # NOVO
from permissoes import perfil_requerido      # NOVO

pecas_bp = Blueprint('pecas', __name__)


@pecas_bp.route('/', methods=['GET'])
def listar_pecas():
    pecas = Peca.query.all()
    return jsonify([{
        "id": peca.id,
        "nome": peca.nome,
        "descricao": peca.descricao,
        "preco": peca.preco,
        "estoque": peca.estoque
    } for peca in pecas])


@pecas_bp.route('/<int:id>', methods=['GET'])
def obter_peca(id):
    peca = Peca.query.get_or_404(id)
    return jsonify({
        "id": peca.id,
        "nome": peca.nome,
        "descricao": peca.descricao,
        "preco": peca.preco,
        "estoque": peca.estoque
    })


@pecas_bp.route('/', methods=['POST'])
@jwt_required()                                # NOVO
def criar_peca():
    data = request.get_json()

    if not data.get('nome') or data.get('preco') is None:
        return jsonify({"erro": "nome e preco são obrigatórios"}), 400

    peca = Peca(
        nome=data['nome'],
        descricao=data.get('descricao', ''),
        preco=data['preco'],
        estoque=data.get('estoque', 0)
    )
    db.session.add(peca)
    try:                                       # NOVO
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "preco e estoque não podem ser negativos"}), 400
    return jsonify({"id": peca.id, "nome": peca.nome, "estoque": peca.estoque}), 201


@pecas_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()                                # NOVO
def atualizar_peca(id):
    peca = Peca.query.get_or_404(id)
    data = request.get_json()

    peca.nome = data.get('nome', peca.nome)
    peca.descricao = data.get('descricao', peca.descricao)
    peca.preco = data.get('preco', peca.preco)
    peca.estoque = data.get('estoque', peca.estoque)

    try:                                       # NOVO
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "preco e estoque não podem ser negativos"}), 400
    return jsonify({"mensagem": "Peça atualizada com sucesso", "estoque": peca.estoque})


@pecas_bp.route('/<int:id>', methods=['DELETE'])
@perfil_requerido('admin')                     # NOVO
def deletar_peca(id):
    peca = Peca.query.get_or_404(id)
    db.session.delete(peca)
    try:                                       # NOVO
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "peça já foi usada em ordens de serviço ou vendas e não pode ser removida"}), 409
    return jsonify({"mensagem": "Peça deletada com sucesso"})
