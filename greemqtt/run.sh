set -e

bashio::log.info "Starting Gree MQTT Bridge..."

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
        export NETWORK=$(bashio::config 'network | jq -r '.[].ip' | paste -sd, -)
    fi
    if bashio::config.has_value 'subnet'; then
        export SUBNET=$(bashio::config 'subnet')
    fi
    if bashio::config.has_value 'udp_port'; then
        export UDP_PORT=$(bashio::config 'udp_port')
    fi
}

run_application() {
    bashio::log.info "🚀 Launching GreeMQTT..."
    # zamiast python -m GreeMQTT
    exec uv run GreeMQTT
}

main() {
    setup_environment
    run_application
}

main "$@"
