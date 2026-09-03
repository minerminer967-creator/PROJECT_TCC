from flask import Blueprint, jsonify
from extensions import db
from models import cliente

clientes_bp = Blueprint('clientes', __name__)


@clientes_bp.route('/clientes', methods=['GET'])
def listar_clientes():
    clientes = cliente.query.all()
    clientes_list = [cliente.to_dict() for cliente in clientes]
    return jsonify(clientes_list)


@clientes_bp.route('/clientes/<int:id>', methods=['POST'])
def criar_cliente(id):
    dados = request.get_json()
    if not dados.get("nome"):
        return jsonify({"error": "O campo 'nome' é obrigatório"}), 400

    cliente = Cliente(nome=dados["nome"], telefone=dados.get(
        "telefone"), email=dados.get("email"))
    db.session.add(cliente)
    db.session.commit()
    return jsonify({"message": "Cliente criado com sucesso", "cliente": cliente.to_dict()}), 201


@clientes_bp.route('/clientes/<int:id>', methods=['PUT'])
def atualizar_cliente(id):
    cliente = Cliente.query.get_or_404(id)
    dados = request.get_json()
    cliente.nome = dados.get("nome", cliente.nome)
    cliente.telefone = dados.get("telefone", cliente.telefone)
    cliente.email = dados.get("email", cliente.email)
    db.session.commit()
    return jsonify({"message": "Cliente atualizado com sucesso", "cliente": cliente.to_dict()}), 200


@clientes_bp.route('/clientes/<int:id>', methods=['DELETE'])
def deletar_cliente(id):
    cliente = Cliente.query.get_or_404(id)
    db.session.delete(cliente)
    db.session.commit()
    return jsonify({"message": "Cliente deletado com sucesso"}), 200
