def format_error_message(message):
    """Standardize error message format"""
    if isinstance(message, dict):
        # If message is a dict of validation errors, take the first error
        for field, errors in message.items():
            if isinstance(errors, list):
                return {"Details": errors[0]}
            return {"Details": str(errors)}
    return {"Details": str(message)} 