FROM monteship/greemqtt:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      jq bash \
    && rm -rf /var/lib/apt/lists/*

# Copy the fixed main file to override the original
COPY __main__.py /app/GreeMQTT/__main__.py

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]