from flask import Blueprint, request, jsonify
from extensions import db
from models import OrdemServico

os_bp = Blueprint('ordem_servico', __name__)


@os_bp.route("/", methods=["GET"])
def listar_ordem_servico():
    ordem_servicos = OrdemServico.query.all()
    return jsonify([{
        "id": o.id,
        "equipamento_id": o.equipamento_id,
        "problema": o.problema_relatado,
        "diagnostico": o.diagnostico,
        "status": o.status,
        "peca_id": o.peca_id,
        "valor": o.valor,
        "pago": o.pago
    } for o in ordem_servicos])


@os_bp.route("/", methods=["POST"])
def criar_ordem_servico():
    data = request.get_json()
    if not data.get('equipamento_id') or not data.get('problema'):
        return jsonify({"erro": "equipamento_id e problema são obrigatórios"}), 400

    ordem_servico = OrdemServico(
        equipamento_id=data['equipamento_id'],
        problema_relatado=data['problema'],
        diagnostico=data.get('diagnostico'),
        status=data.get('status', 'aguardando_diagnostico'),
        peca_id=data.get('peca_id'),
        valor=data.get('valor', 0.0),
        pago=data.get('pago', False)
    )
    db.session.add(ordem_servico)
    db.session.commit()
    return jsonify({"id": ordem_servico.id, "status": ordem_servico.status}), 201


@os_bp.route("/<int:id>", methods=["PUT"])
def atualizar_ordem_servico(id):
    ordem_servico = OrdemServico.query.get_or_404(id)
    data = request.get_json()

    ordem_servico.diagnostico = data.get(
        'diagnostico', ordem_servico.diagnostico)
    ordem_servico.status = data.get('status', ordem_servico.status)
    ordem_servico.peca_id = data.get('peca_id', ordem_servico.peca_id)
    ordem_servico.valor = data.get('valor', ordem_servico.valor)
    ordem_servico.pago = data.get('pago', ordem_servico.pago)

    db.session.commit()
    return jsonify({"message": "Ordem de serviço atualizada com sucesso.", "status": ordem_servico.status})
