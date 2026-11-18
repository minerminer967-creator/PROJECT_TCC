from functools import wraps
from flask import jsonify
from flask_jwt_extended import verify_jwt_in_request, get_jwt


def perfil_requerido(*perfis):
    """Exige token válido e que o perfil esteja na lista."""
    def decorador(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            if get_jwt().get("perfil") not in perfis:
                return jsonify({"erro": "sem permissão para esta ação"}), 403
            return fn(*args, **kwargs)
        return wrapper
    return decorador
