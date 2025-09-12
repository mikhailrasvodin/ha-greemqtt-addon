# Używamy bazowego obrazu Home Assistant
ARG BUILD_FROM
FROM $BUILD_FROM

# Instalujemy wymagane pakiety
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    jq \
    nc-openbsd

# Pobieramy i instalujemy GreeMQTT
WORKDIR /app
RUN git clone https://github.com/monteship/GreeMQTT.git . && \
    pip3 install -e .

# Kopiujemy skrypt startowy
COPY run.sh /
RUN chmod a+x /run.sh

# Tworzymy katalogi
RUN mkdir -p /data /config

# Punkt wejścia
CMD [ "/run.sh" ]