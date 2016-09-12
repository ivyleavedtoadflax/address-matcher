from __future__ import unicode_literals

from django.db import models

class Address(models.Model):
    line1 = models.CharField(max_length=200, blank=True)
    line2 = models.CharField(max_length=200, blank=True)
    line3 = models.CharField(max_length=200, blank=True)
    line4 = models.CharField(max_length=200, blank=True)
    line5 = models.CharField(max_length=200, blank=True)
    line6 = models.CharField(max_length=200, blank=True)
    line7 = models.CharField(max_length=200, blank=True)

class User(models.Model):
    name = models.CharField(max_length=200)

class Match(models.Model):
    test_address = models.ForeignKey(Address)
    user = models.ForeignKey(User)
    uprn = models.CharField(max_length=20)
    date = models.DateField()
