def parse_pg_error_code(e) -> str:
    parts = e.pgerror.split('[')
    if len(parts) < 2:
        return 'UNKNOWN'
    return parts[1].split(']')[0]

def parse_pg_error_message(msg: str) -> str:
    return msg.split(']')[1].split('\n')[0].strip()