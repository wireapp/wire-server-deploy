# ansible-based configuration

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. The documentation and code under this folder is meant to help with that.

## Development setup

```
# install 'poetry' (python dependency management)
curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python

cd ansible
poetry install
```
