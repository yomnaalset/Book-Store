"""
Utility functions for the bookstore application.
"""
from django.conf import settings
import re


def format_error_message(error):
    """
    Format error messages for consistent API responses.
    """
    if isinstance(error, str):
        return error
    elif hasattr(error, '__str__'):
        return str(error)
    else:
        return "An unexpected error occurred"


def get_translated_choices(choices, language=None):
    """
    Get translated choices for model fields.
    
    Args:
        choices: List of tuples (value, label) or TextChoices class
        language: Language code to translate to (defaults to current language)
    
    Returns:
        List of tuples with translated labels
    """
    if hasattr(choices, 'choices'):
        # Handle TextChoices
        return [(choice[0], choice[1]) for choice in choices.choices]
    elif isinstance(choices, (list, tuple)):
        # Handle regular choices
        return [(choice[0], choice[1]) for choice in choices]
    else:
        return choices


def get_language_context(request):
    """
    Get comprehensive language context for the request.
    
    Args:
        request: Django request object
    
    Returns:
        Dictionary with language context information
    """
    language = getattr(request, 'LANGUAGE_CODE', settings.LANGUAGE_CODE)
    
    context = {
        'current_language': language,
        'is_rtl': language == 'ar',
        'language_name': dict(settings.LANGUAGES).get(language, language),
        'supported_languages': settings.LANGUAGES,
        'default_language': settings.LANGUAGE_CODE,
    }
    
    # Add formatting preferences
    if hasattr(request, 'LANGUAGE_FORMATTING'):
        context['formatting'] = request.LANGUAGE_FORMATTING
    
    return context


def translate_model_field(model_instance, field_name, language=None):
    """
    Get translated value for a model field.
    
    Args:
        model_instance: Django model instance
        field_name: Name of the field to translate
        language: Language code (defaults to current language)
    
    Returns:
        Translated field value
    """
    if not hasattr(model_instance, field_name):
        return None
    
    field_value = getattr(model_instance, field_name)
    
    # Handle choices fields
    field = model_instance._meta.get_field(field_name)
    if hasattr(field, 'choices') and field.choices:
        # Get the display value for choices
        display_value = getattr(model_instance, f'get_{field_name}_display')()
        return display_value
    
    # Handle regular fields
    return field_value


def get_translated_model_summary(model_instance, language=None):
    """
    Get a translated summary of a model instance.
    
    Args:
        model_instance: Django model instance
        language: Language code (defaults to current language)
    
    Returns:
        Dictionary with translated field values
    """
    if not model_instance:
        return {}
    
    summary = {}
    
    # Get translatable fields
    for field in model_instance._meta.fields:
        if field.name in ['id', 'created_at', 'updated_at']:
            continue
            
        # Handle choices fields
        if hasattr(field, 'choices') and field.choices:
            try:
                display_method = getattr(model_instance, f'get_{field.name}_display')
                summary[field.name] = display_method()
            except:
                summary[field.name] = getattr(model_instance, field.name)
        else:
            summary[field.name] = getattr(model_instance, field.name)
    
    return summary


def format_currency(amount, language=None, currency_symbol=None):
    """
    Format currency amount based on language.
    
    Args:
        amount: Decimal amount
        language: Language code (defaults to current language)
        currency_symbol: Currency symbol to use
    
    Returns:
        Formatted currency string
    """
    if language is None:
        from django.utils.translation import get_language
        language = get_language()
    
    if currency_symbol is None:
        currency_symbol = 'ر.س' if language == 'ar' else '$'
    
    # Format based on language
    if language == 'ar':
        # Arabic formatting: ر.س 100.00
        return f"{currency_symbol} {amount:,.2f}"
    else:
        # English formatting: $100.00
        return f"{currency_symbol}{amount:,.2f}"


def format_date(date_obj, language=None, format_type='date'):
    """
    Format date based on language.
    
    Args:
        date_obj: Date object
        language: Language code (defaults to current language)
        format_type: Type of format ('date', 'time', 'datetime')
    
    Returns:
        Formatted date string
    """
    if language is None:
        from django.utils.translation import get_language
        language = get_language()
    
    if not date_obj:
        return ""
    
    # Format based on language
    if language == 'ar':
        if format_type == 'date':
            return date_obj.strftime('%Y-%m-%d')
        elif format_type == 'time':
            return date_obj.strftime('%H:%M')
        elif format_type == 'datetime':
            return date_obj.strftime('%Y-%m-%d %H:%M')
    else:
        if format_type == 'date':
            return date_obj.strftime('%m/%d/%Y')
        elif format_type == 'time':
            return date_obj.strftime('%H:%M')
        elif format_type == 'datetime':
            return date_obj.strftime('%m/%d/%Y %H:%M')
    
    return str(date_obj)


def get_language_specific_text(text_dict, language=None, fallback='en'):
    """
    Get language-specific text from a dictionary.
    
    Args:
        text_dict: Dictionary with language codes as keys
        language: Language code to get text for
        fallback: Fallback language if requested language not found
    
    Returns:
        Text in the requested language or fallback
    """
    if language is None:
        from django.utils.translation import get_language
        language = get_language()
    
    # Try to get text in requested language
    if language in text_dict:
        return text_dict[language]
    
    # Try fallback language
    if fallback in text_dict:
        return text_dict[fallback]
    
    # Return first available text or empty string
    return next(iter(text_dict.values()), "")


def sanitize_filename(filename):
    """
    Sanitize filename for safe file uploads.
    
    Args:
        filename: Original filename
    
    Returns:
        Sanitized filename
    """
    # Remove or replace unsafe characters
    filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
    
    # Limit length
    if len(filename) > 255:
        name, ext = filename.rsplit('.', 1) if '.' in filename else (filename, '')
        filename = name[:255-len(ext)-1] + ('.' + ext if ext else '')
    
    return filename


def validate_file_extension(filename, allowed_extensions):
    """
    Validate file extension.
    
    Args:
        filename: Filename to validate
        allowed_extensions: List of allowed extensions (with or without dot)
    
    Returns:
        Boolean indicating if extension is valid
    """
    if not filename:
        return False
    
    # Get file extension
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
    
    # Normalize extensions (remove dots if present)
    allowed_extensions = [ext.lower().lstrip('.') for ext in allowed_extensions]
    
    return ext in allowed_extensions


def get_file_size_display(size_bytes):
    """
    Convert file size in bytes to human-readable format.
    
    Args:
        size_bytes: File size in bytes
    
    Returns:
        Human-readable file size string
    """
    if size_bytes == 0:
        return "0 B"
    
    size_names = ["B", "KB", "MB", "GB", "TB"]
    import math
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    
    return f"{s} {size_names[i]}"