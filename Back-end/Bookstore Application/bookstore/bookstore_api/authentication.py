from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from django.contrib.auth import get_user_model

User = get_user_model()

class CustomJWTAuthentication(JWTAuthentication):
    """
    Custom JWT authentication that properly handles user_id conversion.
    """
    
    def get_user(self, validated_token):
        """
        Attempts to find and return a user using the given validated token.
        """
        try:
            user_id = validated_token.get('user_id')
            if user_id is None:
                raise InvalidToken('Token contained no recognizable user identification')
            
            # Convert string user_id to integer if needed
            if isinstance(user_id, str):
                try:
                    user_id = int(user_id)
                except ValueError:
                    raise InvalidToken('Token contained invalid user identification')
            
            user = User.objects.get(id=user_id)
            return user
        except User.DoesNotExist:
            raise InvalidToken('User not found')
        except Exception as e:
            raise InvalidToken(f'Token is invalid: {str(e)}')

