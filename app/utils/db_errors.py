def parse_pg_error_code(pgerror:str) -> str:
    if pgerror is None:
        return 'UNKNOWN'
    parts = pgerror.split('[')
    if len(parts) < 2:
        return 'UNKNOWN'
    return parts[1].split(']')[0]

def parse_pg_error_message(pgerror: str) -> str:
    if pgerror is None: 
        return 'An unexpected error occurred'
    parts = pgerror.split(']')
    if len(parts) < 2:
        return 'An unexpected error occurred'
    return parts[1].split('\n')[0].strip()