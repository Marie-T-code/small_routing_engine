# db_errors.py — helpers to read the custom error tags raised by our SQL functions
# Layer : Utils (used by repositories only)
# SQL messages look like "[DOMAIN:CODE] human-readable message".

def parse_pg_error_code(message: str | None) -> str:
    if message is None:
        return 'UNKNOWN'
    parts = message.split('[')
    if len(parts) < 2:
        return 'UNKNOWN'
    return parts[1].split(']')[0]


def parse_pg_error_message(message: str | None) -> str:
    if message is None:
        return 'An unexpected error occurred'
    parts = message.split(']', 1)
    if len(parts) < 2:
        return 'An unexpected error occurred'
    return parts[1].strip()