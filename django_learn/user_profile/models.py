from django.contrib.auth.models import User
from django.core.validators import MinLengthValidator
from django.db import models


# Create your models here.
class Profile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )
    mbti = models.CharField(max_length=4, validators=[MinLengthValidator(4)])
