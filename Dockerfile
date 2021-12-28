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

# copy everything from /opt
COPY --from=python_builder /opt/venv /opt/venv
COPY --from=python_builder /app /app
ENV PATH="/opt/venv/bin:$PATH"

# Install Kogito JIT Executor to execute and validate DMN models
RUN mkdir -p /usr/share/man/man1 && \
  apt-get update && apt-get install -y default-jdk wget git

RUN wget https://ftp.cixug.es/apache/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz && \
  tar -xf apache-maven-3.8.1-bin.tar.gz -C /usr/local

RUN wget https://github.com/gpou/kogito-apps/archive/jitrunner-improvements.tar.gz && \
  tar -xf jitrunner-improvements.tar.gz -C /usr/local && \
  cd /usr/local/kogito-apps-jitrunner-improvements/jitexecutor && \
  export M2_HOME=/usr/local/apache-maven-3.8.1 && \
  export M2=$M2_HOME/bin && \
  export MAVEN_OPTS="-Xms256m -Xmx512m" && \
  export PATH=$M2:$PATH && \
  mvn clean package -DskipTests

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
