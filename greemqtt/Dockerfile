# Używamy istniejącego obrazu jako bazy
FROM monteship/greemqtt:latest

# Dodajemy s6-overlay dla lepszej integracji z Home Assistant
ARG BUILD_FROM
ARG BUILD_ARCH
ARG BUILD_VERSION

# Instalujemy bashio i s6-overlay
RUN apk add --no-cache \
    bashio \
    jq

# Kopiujemy pliki konfiguracyjne
COPY rootfs /

# Kopiujemy skrypt startowy
COPY run.sh /
RUN chmod a+x /run.sh

# Ustawiamy punkt wejścia
ENTRYPOINT ["/run.sh"]