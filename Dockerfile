FROM python:3.7-slim as python_builder
RUN apt-get update -qq && \
  apt-get install -y --no-install-recommends \
  build-essential \
  curl

# install poetry
# keep this in sync with the version in pyproject.toml and Dockerfile
ENV POETRY_VERSION 1.1.4
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python
ENV PATH "/root/.poetry/bin:/opt/venv/bin:${PATH}"

# install dependencies
COPY . /app/
RUN python -m venv /opt/venv && \
  . /opt/venv/bin/activate && \
  pip install --no-cache-dir -U pip && \
  cd /app && \
  poetry install --no-dev --no-interaction

# FIXME: install this dependencies using poetry
RUN pip install --no-cache-dir opentelemetry-sdk && \
  pip install --no-cache-dir opentelemetry-instrumentation && \
  pip install --no-cache-dir opentelemetry-instrumentation-aiohttp-client && \
  pip install --no-cache-dir opentelemetry-instrumentation-sqlalchemy && \
  pip install --no-cache-dir opentelemetry-instrumentation-logging && \
  pip install --no-cache-dir opentelemetry-exporter-jaeger && \
  pip install --no-cache-dir jaeger-client && \
  pip install --no-cache-dir sanic-prometheus

# FROM golang:1.17 as builder
# RUN go install github.com/DataDog/temporalite/cmd/temporalite@0.0.0

# start a new build stage
FROM python:3.7-slim

# copy everything from /opt
COPY --from=python_builder /opt/venv /opt/venv
COPY --from=python_builder /app /app
ENV PATH="/opt/venv/bin:$PATH"

# install go and temporalite
RUN apt-get update
RUN apt-get install -y wget gcc
RUN wget https://dl.google.com/go/go1.17.5.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.17.5.linux-amd64.tar.gz
RUN /usr/local/go/bin/go install github.com/DataDog/temporalite/cmd/temporalite@latest

# install rvm and ruby 3.0.2
RUN apt-get install -y curl g++ gcc autoconf automake bison libc6-dev libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev make pkg-config sqlite3 zlib1g-dev libgmp-dev libreadline-dev libssl-dev gpg procps
RUN gpg --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 3.0.2"
RUN /bin/bash -l -c "rvm use 3.0.2 --default"
RUN /bin/bash -l -c "gem install bundler"
# to be able to install gems from github
RUN apt-get install -y git

# RUN apt-get update
# RUN apt-get install -y wget gcc

# update permissions & change user
RUN chgrp -R 0 /app && chmod -R g=u /app
USER 1001

# change shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# create a mount point for custom actions and the entry point
WORKDIR /app
EXPOSE 5055
ENTRYPOINT ["./entrypoint.sh"]
CMD ["start", "--actions", "actions"]
