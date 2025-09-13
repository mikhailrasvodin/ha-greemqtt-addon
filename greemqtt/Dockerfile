FROM monteship/greemqtt:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      jq netcat-openbsd curl git bash \
    && rm -rf /var/lib/apt/lists/*

# Install bashio properly
RUN git clone --depth 1 https://github.com/hassio-addons/bashio.git /usr/lib/bashio \
    && rm -rf /usr/lib/bashio/.git \
    && ln -s /usr/lib/bashio/bin/bashio /usr/local/bin/bashio \
    && chmod +x /usr/local/bin/bashio

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]