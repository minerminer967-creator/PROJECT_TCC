from flask import Blueprint, request, jsonify
from extensions import db
from models import Equipamento, Cliente
from sqlalchemy.exc import IntegrityError
from flask_jwt_extended import jwt_required
from permissoes import perfil_requerido

equipamento_bp = Blueprint('equipamento', __name__)


@equipamento_bp.route("/", methods=["GET"])
def listar_equipamentos():
    equipamentos = Equipamento.query.all()
    return jsonify([{
        "id": e.id,
        "cliente_id": e.cliente_id,
        "nome": e.nome,
        "descricao": e.descricao
    } for e in equipamentos])


@equipamento_bp.route("/<int:id>", methods=["GET"])
def obter_equipamento(id):
    equipamento = Equipamento.query.get_or_404(id)
    return jsonify({
        "id": equipamento.id,
        "cliente_id": equipamento.cliente_id,
        "nome": equipamento.nome,
        "descricao": equipamento.descricao
    })


@equipamento_bp.route("/", methods=["POST"])
@jwt_required()
def criar_equipamento():
    data = request.get_json()
    if not data.get('cliente_id') or not data.get('nome'):
        return jsonify({"erro": "cliente_id e nome são obrigatórios"}), 400

    cliente = Cliente.query.get(data['cliente_id'])
    if not cliente:
        return jsonify({"erro": "cliente_id informado não existe"}), 404

    equipamento = Equipamento(
        cliente_id=data['cliente_id'],
        nome=data['nome'],
        descricao=data.get('descricao', '')
    )
    db.session.add(equipamento)
    db.session.commit()
    return jsonify({"id": equipamento.id, "nome": equipamento.nome}), 201


@equipamento_bp.route("/<int:id>", methods=["PUT"])
@jwt_required()
def atualizar_equipamento(id):
    equipamento = Equipamento.query.get_or_404(id)
    data = request.get_json()
    equipamento.nome = data.get('nome', equipamento.nome)
    equipamento.descricao = data.get('descricao', equipamento.descricao)
    db.session.commit()
    return jsonify({"mensagem": "equipamento atualizado"})


@equipamento_bp.route("/<int:id>", methods=["DELETE"])
@perfil_requerido('admin')
def deletar_equipamento(id):
    equipamento = Equipamento.query.get_or_404(id)
    db.session.delete(equipamento)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "equipamento possui ordens de serviço e não pode ser removido"}), 409
    return jsonify({"mensagem": "equipamento removido"})
