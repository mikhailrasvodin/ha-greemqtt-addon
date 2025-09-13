FROM monteship/greemqtt:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      jq netcat-openbsd curl git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/hassio-addons/bashio.git /usr/lib/bashio \
    && rm -rf /usr/lib/bashio/.git

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
