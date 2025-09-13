#!/bin/bash
set -e

echo "🏠 Starting Gree MQTT Bridge Add-on..."

# Read configuration from options.json
CONFIG_PATH=/data/options.json

get_config() {
    local key="$1"
    local default="$2"
    
    if [ -f "$CONFIG_PATH" ]; then
        jq -r ".$key // \"$default\"" "$CONFIG_PATH" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

has_config_value() {
    local key="$1"
    
    if [ -f "$CONFIG_PATH" ]; then
        local value=$(jq -r ".$key // null" "$CONFIG_PATH" 2>/dev/null)
        [ "$value" != "null" ] && [ "$value" != "" ]
    else
        false
    fi
}

setup_environment() {
    export MQTT_BROKER=$(get_config 'mqtt_host' 'core-mosquitto')
    export MQTT_PORT=$(get_config 'mqtt_port' '1883')
    export MQTT_USER=$(get_config 'mqtt_username' '')
    export MQTT_PASSWORD=$(get_config 'mqtt_password' '')
    export MQTT_TOPIC=$(get_config 'mqtt_topic' 'gree')
    export UPDATE_INTERVAL=$(get_config 'update_interval' '3')
    export LOG_LEVEL=$(get_config 'log_level' 'INFO')
    export ADAPTIVE_POLLING_TIMEOUT=$(get_config 'adaptive_polling_timeout' '45')
    export ADAPTIVE_FAST_INTERVAL=$(get_config 'adaptive_fast_interval' '0.8')
    export MQTT_MESSAGE_WORKERS=$(get_config 'mqtt_message_workers' '3')
    export IMMEDIATE_RESPONSE_TIMEOUT=$(get_config 'immediate_response_timeout' '5')

    # Handle network array
    if has_config_value 'network'; then
        export NETWORK=$(jq -r '.network[]?.ip // empty' "$CONFIG_PATH" 2>/dev/null | paste -sd, - || echo "")
    fi

    # Handle subnet
    if has_config_value 'subnet'; then
        export SUBNET=$(get_config 'subnet' '')
    fi

    # Handle UDP port  
    if has_config_value 'udp_port'; then
        export UDP_PORT=$(get_config 'udp_port' '')
    fi

    echo "Configuration loaded:"
    echo "- MQTT Broker: ${MQTT_BROKER}"
    echo "- MQTT Port: ${MQTT_PORT}"
    echo "- MQTT User: ${MQTT_USER}"
    echo "- MQTT Topic: ${MQTT_TOPIC}"
    echo "- Update Interval: ${UPDATE_INTERVAL}s"
    echo "- Adaptive Polling Timeout: ${ADAPTIVE_POLLING_TIMEOUT}s"
    echo "- Fast Polling Interval: ${ADAPTIVE_FAST_INTERVAL}s"
    echo "- MQTT Workers: ${MQTT_MESSAGE_WORKERS}"
    echo "- Immediate Response Timeout: ${IMMEDIATE_RESPONSE_TIMEOUT}s"

    if [ -n "${NETWORK:-}" ]; then
        echo "- Device Network: ${NETWORK}"
    else
        echo "- Device Discovery: Auto-scan enabled"
    fi

    if [ -n "${SUBNET:-}" ]; then
        echo "- Subnet: ${SUBNET}"
    fi

    if [ -n "${UDP_PORT:-}" ]; then
        echo "- UDP Port: ${UDP_PORT}"
    fi
}

run_application() {
    echo "🚀 Launching GreeMQTT..."
    exec uv run GreeMQTT
}

main() {
    setup_environment
    run_application
}

trap 'echo "🛑 Shutting down Gree MQTT Bridge..."; exit 0' SIGTERM SIGINT

main "$@"