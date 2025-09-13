#!/usr/bin/env bashio
set -e

bashio::log.info "🏠 Starting Gree MQTT Bridge Add-on..."

setup_environment() {
    export MQTT_BROKER=$(bashio::config 'mqtt_host' 'core-mosquitto')
    export MQTT_PORT=$(bashio::config 'mqtt_port' '1883')
    export MQTT_USER=$(bashio::config 'mqtt_username' '')
    export MQTT_PASSWORD=$(bashio::config 'mqtt_password' '')
    export MQTT_TOPIC=$(bashio::config 'mqtt_topic' 'gree')
    export UPDATE_INTERVAL=$(bashio::config 'update_interval' '3')
    export LOG_LEVEL=$(bashio::config 'log_level' 'INFO')
    export ADAPTIVE_POLLING_TIMEOUT=$(bashio::config 'adaptive_polling_timeout' '45')
    export ADAPTIVE_FAST_INTERVAL=$(bashio::config 'adaptive_fast_interval' '0.8')
    export MQTT_MESSAGE_WORKERS=$(bashio::config 'mqtt_message_workers' '3')
    export IMMEDIATE_RESPONSE_TIMEOUT=$(bashio::config 'immediate_response_timeout' '5')

    if bashio::config.has_value 'network'; then
        export NETWORK=$(
            bashio::config 'network' \
                | jq -r '.[].ip' \
                | paste -sd, -
        )
    fi

    if bashio::config.has_value 'subnet'; then
        export SUBNET=$(bashio::config 'subnet')
    fi

    if bashio::config.has_value 'udp_port'; then
        export UDP_PORT=$(bashio::config 'udp_port')
    fi

    bashio::log.info "Configuration loaded:"
    bashio::log.info "- MQTT Broker: ${MQTT_BROKER}"
    bashio::log.info "- MQTT Port: ${MQTT_PORT}"
    bashio::log.info "- MQTT User: ${MQTT_USER}"
    bashio::log.info "- MQTT Topic: ${MQTT_TOPIC}"
    bashio::log.info "- Update Interval: ${UPDATE_INTERVAL}s"
    bashio::log.info "- Adaptive Polling Timeout: ${ADAPTIVE_POLLING_TIMEOUT}s"
    bashio::log.info "- Fast Polling Interval: ${ADAPTIVE_FAST_INTERVAL}s"
    bashio::log.info "- MQTT Workers: ${MQTT_MESSAGE_WORKERS}"
    bashio::log.info "- Immediate Response Timeout: ${IMMEDIATE_RESPONSE_TIMEOUT}s"

    if [ -n "${NETWORK:-}" ]; then
        bashio::log.info "- Device Network: ${NETWORK}"
    else
        bashio::log.info "- Device Discovery: Auto-scan enabled"
    fi

    if [ -n "${SUBNET:-}" ]; then
        bashio::log.info "- Subnet: ${SUBNET}"
    fi

    if [ -n "${UDP_PORT:-}" ]; then
        bashio::log.info "- UDP Port: ${UDP_PORT}"
    fi
}

run_application() {
    bashio::log.info "🚀 Launching GreeMQTT..."
    exec uv run GreeMQTT
}

main() {
    setup_environment
    run_application
}

trap 'bashio::log.info "🛑 Shutting down Gree MQTT Bridge..."; exit 0' SIGTERM SIGINT

main "$@"