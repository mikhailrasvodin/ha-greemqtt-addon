ARG BUILD_FROM=ghcr.io/hassio-addons/base:18.1.1
FROM $BUILD_FROM

RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    jq \
    nc-openbsd

WORKDIR /app
RUN git clone https://github.com/monteship/GreeMQTT.git . && \
    pip3 install -e .

COPY run.sh /
RUN chmod a+x /run.sh

RUN mkdir -p /data /config

CMD [ "/run.sh" ]