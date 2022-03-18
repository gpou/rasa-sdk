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

# start a new build stage
FROM python:3.7-slim

# install ruby, mysql client, and dependencies
RUN apt-get update -qq && apt-get install -y g++ gcc autoconf automake bison libc6-dev \
        libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool \
        libyaml-dev make pkg-config sqlite3 zlib1g-dev libgmp-dev \
        libreadline-dev libssl-dev gnupg2 procps git curl default-libmysqlclient-dev cmake
RUN gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN /usr/local/rvm/bin/rvm install 3.0.2
RUN /usr/local/rvm/bin/rvm alias create default ruby-3.0.2

# copy everything from /opt
COPY --from=python_builder /opt/venv /opt/venv
COPY --from=python_builder /app /app
ENV PATH="/opt/venv/bin:$PATH"

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
