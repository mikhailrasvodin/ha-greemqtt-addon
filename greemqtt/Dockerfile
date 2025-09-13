FROM monteship/greemqtt:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      jq netcat-openbsd curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install bashio

COPY run.sh /run.sh
RUN chmod +x /run.sh

RUN mkdir -p /data /config

CMD [ "/run.sh" ]
