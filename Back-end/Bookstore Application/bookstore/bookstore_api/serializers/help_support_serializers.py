from rest_framework import serializers
from ..models import FAQ, UserGuide, TroubleshootingGuide, SupportContact


class FAQSerializer(serializers.ModelSerializer):
    class Meta:
        model = FAQ
        fields = ['id', 'question', 'answer', 'category', 'order', 'created_at', 'updated_at']


class UserGuideSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserGuide
        fields = ['id', 'title', 'content', 'section', 'order', 'created_at', 'updated_at']


class TroubleshootingGuideSerializer(serializers.ModelSerializer):
    class Meta:
        model = TroubleshootingGuide
        fields = ['id', 'title', 'description', 'solution', 'category', 'order', 'created_at', 'updated_at']


class SupportContactSerializer(serializers.ModelSerializer):
    contact_type_display = serializers.CharField(source='get_contact_type_display', read_only=True)
    
    class Meta:
        model = SupportContact
        fields = ['id', 'contact_type', 'contact_type_display', 'title', 'description', 
                 'contact_info', 'is_available', 'available_hours', 'is_admin_only', 
                 'order', 'created_at', 'updated_at']


class HelpSupportDataSerializer(serializers.Serializer):
    """Combined serializer for all help and support data"""
    faqs = FAQSerializer(many=True)
    user_guides = UserGuideSerializer(many=True)
    troubleshooting_guides = TroubleshootingGuideSerializer(many=True)
    support_contacts = SupportContactSerializer(many=True)
