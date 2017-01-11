from django.shortcuts import render, get_object_or_404
from django.http import HttpResponse, JsonResponse
from django.template import loader
from django.db.models import Count
from django.utils.safestring import mark_safe
from django.views.decorators.csrf import csrf_exempt
from datetime import datetime
from random import randint
from hashlib import md5
from models import Address, Match, User, RegisterAddress
from elasticsearch import Elasticsearch
from itertools import groupby
import os
import json
import re
import random


def index(request):
    template = loader.get_template('main.html')
    context = {}
    return HttpResponse(template.render(context, request))


def help(request):
    template = loader.get_template('help.html')
    context = {}
    return HttpResponse(template.render(context, request))


def count_matches():
    # compute how many times each address is referred to in matches
    addresses = Address.objects.all()
    matches = Match.objects.all()

    # dictionary: address_id -> int (reference count)
    count_matches = {}

    for address in addresses:
        count_matches[address.id] = 0;

    for match in matches:
        count_matches[match.test_address_id] = count_matches[match.test_address_id] + 1

    return count_matches

def wordy_match(nb_matches):
    if nb_matches == 0:
        return "Not yet matched"
    elif nb_matches == 1:
        return "Matched once"
    elif nb_matches == 2:
        return "Matched twice"
    else:
        return "Matched " + str(nb_matches) + " times"


def occurrence_dict(counts):
    # generate dictionary that gives the number of addresses
    # for each occurrence count:
    # count -> how many addresses have that count
    addresses = Address.objects.all()
    matches = Match.objects.all()

    occurrence_nbaddresses = {}
    for occurrence in range(0, len(matches)):
        occurrence_nbaddresses[occurrence] = \
            len({k: v for k, v in counts.iteritems() if v == occurrence})

    non_zero = [[wordy_match(k), v] for k, v in occurrence_nbaddresses.iteritems() if v != 0]
    return non_zero


def make_users_stats():
    matches = Match.objects.all()
    users = User.objects.all()
    users_stats = []
    for user in users:
        user_stats = {
            'name': user.name,
            'id': user.pk,
            'nb_matches': len(Match.objects.filter(user__id = user.pk)),
            'score': user.score
        }
        users_stats.append(user_stats)

    return sorted(users_stats, key=lambda u: u['score'], reverse=True)


def make_stats():
    matches = Match.objects.all()
    users = User.objects.all()
    addresses = Address.objects.all()
    stats = {}
    stats['nb_addresses'] = Address.objects.count()
    stats['nb_matches'] = Match.objects.count()
    stats['occurrences'] = occurrence_dict(count_matches())
    stats['nb_notsure'] = len(Match.objects.filter(uprn__exact = "_notsure_"))
    stats['nb_nomatch'] = len(Match.objects.filter(uprn__exact = "_nomatch_"))
    stats['nb_notsure_ratio'] = round(100*float(stats['nb_notsure']) / stats['nb_matches']) if stats['nb_matches'] > 0 else 0
    stats['nb_nomatch_ratio'] = round(100*float(stats['nb_nomatch']) / stats['nb_matches']) if stats['nb_matches'] > 0 else 0


    agreements = []
    for address in addresses:
        address_matches = Match.objects.filter(test_address__id=address.id)
        nb_matches = len(address_matches)
        if nb_matches > 0:
            agreement_ratio = 100 * address_matches.values('uprn').distinct().count() / nb_matches
            agreements.append([
                nb_matches,
                agreement_ratio,
                "%s: %d matches, %.f%% agreement" % (address.name, nb_matches, agreement_ratio)
            ])

    stats['agreements'] = agreements

    return stats;





def stats(request):
    template = loader.get_template('stats.html')
    stats = make_stats()
    stats['occurrences'] = mark_safe(json.dumps(stats['occurrences']))
    return HttpResponse(template.render(stats, request))


def top_users(request):
    template = loader.get_template('top_users.html')
    context = {
        'users': filter(lambda x: x['score'] != 0, make_users_stats())
    }
    return HttpResponse(template.render(context, request))


def scores_json(request):
    return JsonResponse(make_stats())


def brain(request):
    test_address = request.GET.get('q', '')
    test_address = re.sub(
        r'([+-=&|><!(){}\[\]^"~*?:\\/\'])',
        r'\\\1',
        test_address)

    queryObject = {
        "size": 9,
        "_source": ["parent-address-name", "street-name", "street-town", "name", "address"],
        "query": {
            "match": {
                "_all": test_address
            }
        }
    }

    elasticHost = os.getenv('ELASTICSEARCH_HOST', 'localhost:9200')
    es = Elasticsearch([elasticHost])
    result = es.search(index="flattened", body=json.dumps(queryObject))

    candidate_addresses = []
    for candidate in result['hits']['hits']:
        c = candidate['_source']
        newCandidate = {
            'uprn': c['address'],
            'name': c['name'],
            'street-name': c['street-name'],
            'parent-address-name': c['parent-address-name'],
            'street-town': c['street-town']
        }
        candidate_addresses.append(newCandidate)

    return JsonResponse(candidate_addresses, safe=False)


@csrf_exempt
def send(request):
    user = User.objects.get(pk=request.POST['user'])
    test = Address.objects.get(pk=request.POST['test_address'])
    uprn = request.POST['uprn']

    Match.objects.create(
        test_address = Address.objects.get(pk=request.POST['test_address']),
        user = user,
        uprn = uprn,
        date = datetime.now()
    )

    # If this is a new UPRN, record the address
    if not uprn in ['_nomatch_', '_notsure_']:
        try:
            RegisterAddress.objects.get(uprn=uprn)
        except:
            RegisterAddress(
                uprn = uprn,
                name = request.POST['name'],
                parent_address_name = request.POST['parent_address_name'],
                street_name = request.POST['street_name'],
                street_town = request.POST['street_town']
            ).save()


    # update users' score
    nb_previous_matches = len(Match.objects.filter(
        test_address=test
    ).filter(
        uprn=uprn
    ).exclude(
        user=user
    ))

    # If there have been 3 or more similar matches, score that - 1
    # Otherwise, score 1 point
    if nb_previous_matches >= 3:
        match_score = nb_previous_matches - 1
    else:
        match_score = 1

    user.score = user.score + match_score
    user.save()

    # return user scores for immediate display
    response = {
        'users': make_users_stats(),
        'last_match_score': match_score
    }
    return JsonResponse(response, safe=False)


def next_test_addresses(num):
    # Pick the first among the addresses with the least number of matches
    return Address.objects.annotate(num_matches=Count('match')).order_by('num_matches')[:num]


# Get the next test addresses for a given users
def random_test_addresses(request):
    num = int(request.GET.get('n', 5))
    user_id = int(request.GET.get('userid', 0))

    next_tests = next_test_addresses(num)
    addresses = []

    for test in next_tests:
        addresses.append({
            'id': test.id,
            'name' : test.name,
            'address': test.address
        })


    return JsonResponse(addresses, safe=False)


# Display the page of a specific test address
def test(request, id):
    template = loader.get_template('test.html')
    test = get_object_or_404(Address, pk = id)
    test_matches = Match.objects.filter(test_address__id = id) \
        .order_by('uprn')

    context = {
        'test': test,
        'matches': test_matches
    }
    return HttpResponse(template.render(context, request))


# Display the list of test addresses that have more than 1 matches
def tests(request):
    template = loader.get_template('tests.html')
    addresses = Address.objects.all() \
        .annotate(nb_matches=Count('match'))

    tests = []
    for address in filter(lambda a: a.nb_matches > 1, addresses):
        test = {
            'name': address.name,
            'id': address.id
        }
        matches = Match.objects.filter(test_address__id = address.id)

        t = address.nb_matches
        d = len(set(map(lambda m: m.uprn, matches)))
        n = len(matches.filter(uprn = '_nomatch_'))
        s = len(matches.filter(uprn = '_notsure_'))

        test['nb_matches'] = t
        test['nb_uprns'] = d
        test['no_match'] = n
        test['no_notsure'] = s

        test['confidence'] = 10*(t/(2*d) - 5*(n+s))
        tests.append(test)

    context = {
        'addresses': sorted(tests, key=lambda t: t['confidence'], reverse=True)
    }

    return HttpResponse(template.render(context, request))
