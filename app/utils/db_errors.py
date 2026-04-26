def parse_pg_error_code(e)-> str:
    return e.pgerror.split(']')[0].strip('[]')

def parse_pg_error_message(msg: str) -> str:
    return msg.split(']')[1].strip()