# errors.py — application-wide handlers
# Layer : app
# Translates exceptions raised during a request into JSON HTTP responses:
# ClientError subclasses -> their own status_code; anything else -> logged 500

import logging

from flask import jsonify, request
from werkzeug.exceptions import HTTPException

from utils.exceptions import ClientError

logger = logging.getLogger(__name__)


def _handle_client_error(e: ClientError):
    return jsonify({"status": "error", "message": str(e)}), e.status_code


def _handle_unexpected_errors(e: Exception):
    # Flask's own HTTP errors (404 unknown URL, 405 wrong method) keep their status
    if isinstance(e, HTTPException):
        return e
    logger.exception("Unhandled error on %s", request.path)
    return jsonify({"status": "error", "message": "An unexpected error occurred"}), 500


def register_error_handlers(app) -> None:
    app.register_error_handler(ClientError, _handle_client_error)
    app.register_error_handler(Exception, _handle_unexpected_errors)
