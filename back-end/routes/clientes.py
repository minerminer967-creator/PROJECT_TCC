from flask import Blueprint, request, jsonify
from extensions import db
from models import Cliente
from sqlalchemy.exc import IntegrityError

clientes_bp = Blueprint('clientes', __name__)


@clientes_bp.route('/', methods=['GET'])
def listar_clientes():
    clientes = Cliente.query.all()
    return jsonify([{
        "id": c.id,
        "nome": c.nome,
        "telefone": c.telefone,
        "email": c.email
    } for c in clientes])


@clientes_bp.route('/', methods=['POST'])
def criar_cliente():
    dados = request.get_json()
    if not dados.get("nome"):
        return jsonify({"erro": "O campo 'nome' é obrigatório"}), 400

    cliente = Cliente(
        nome=dados["nome"],
        telefone=dados.get("telefone"),
        email=dados.get("email"),
        endereco=dados.get("endereco", "")
    )
    db.session.add(cliente)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"erro": "telefone ou email já cadastrado"}), 409

    return jsonify({"id": cliente.id, "nome": cliente.nome}), 201


@clientes_bp.route('/<int:id>', methods=['PUT'])
def atualizar_cliente(id):
    cliente = Cliente.query.get_or_404(id)
    dados = request.get_json()
    cliente.nome = dados.get("nome", cliente.nome)
    cliente.telefone = dados.get("telefone", cliente.telefone)
    cliente.email = dados.get("email", cliente.email)
    db.session.commit()
    return jsonify({"message": "Cliente atualizado com sucesso"})


@clientes_bp.route('/<int:id>', methods=['DELETE'])
def deletar_cliente(id):
    cliente = Cliente.query.get_or_404(id)
    db.session.delete(cliente)
    db.session.commit()
    return jsonify({"message": "Cliente deletado com sucesso"})
