# address-matcher
UI for matching addresses


# Local setup

## Requirements:
- python 2.7
- postgresql
- elasticsearch
- conda or venv

## Installation

First create table and user in postgres. If using `postgres` system user

```
sudo -u postgres bash -c "psql -c \"create user matcher with password 'matcher' with createdb;\""
sudo -u postgres bash -c "psql -c \"create database matcher owner matcher;\""
```

Otherwise, use the following commands:

```
psql
create user matcher with password 'matcher'
create database matcher owner matcher
```

Create virtual environemnt using either:

```
conda env create -n address-matcher python=2.7
```
or

```
virtualenv venv
source venv/bin/activate
```

Get requirements:

```
pip install -r requirements.txt
```

Set environmental variables:

```
export DATABASE_URL=postgres://matcher:matcher@localhost:5432/matcher
```

Install elasticsearch locally:

```
brew install elasticsearch
```

Check elasticsearch version

```
elasticsearch --version
```

Start elasticsearch with 

```
elasticsearch
```

Check that elasticsearch is up and running:

```
curl 'http://localhost:9200/?pretty'
```

This should return the repsonse:

```
{
  "name" : "HPKiaki",
  "cluster_name" : "elasticsearch_matthewupson",
  "cluster_uuid" : "nr6_B69pSWW5BDRbW_MZLQ",
  "version" : {
    "number" : "5.2.1",
    "build_hash" : "db0d481",
    "build_date" : "2017-02-09T22:05:32.386Z",
    "build_snapshot" : false,
    "lucene_version" : "6.4.1"
  },
  "tagline" : "You Know, for Search"
}
```

If runnign elasticsearch locally, set the following environmental variable to `localhost`, otherwise set to the address of the remote elasticsearch server.

```
export ELASTICSEARCH_HOST=localhost
```

```
$ ./manage.py migrate
$ ./manage.py import-users < data/sample-users.csv
$ ./manage.py import-addresses "My test addresses" < data/test-addresses-01.tsv
$ ./manage.py runserver
```

## Deploying on Heroku

Following https://devcenter.heroku.com/articles/deploying-python#build-your-app-and-run-it-locally

Check that
```
$ heroku local web
```
works. Then:
```
$ heroku login
$ heroku create
$ heroku config:set DISABLE_COLLECTSTATIC=1
$ heroku config:set ELASTICSEARCH_HOST="http://xyz:8000"
$ git push heroku master
$ heroku run python manage.py migrate
$ heroku run ./manage.py import-users < data/sample-users.csv
$ heroku run ./manage.py import-addresses "Title of your address set" < data/test-addresses-01.tsv
$ heroku open
```
