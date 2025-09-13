#!/bin/bash
set -e

# Try to use bashio, fallback to simple logging if it fails
BASHIO_AVAILABLE=false

if [ -f "/usr/lib/bashio/lib/bashio.sh" ]; then
    # Initialize bashio environment variables
    export __BASHIO_LOG_LEVEL="INFO"
    export SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN:-}"
    
    # Try to source bashio
    if source /usr/lib/bashio/lib/bashio.sh 2>/dev/null; then
        BASHIO_AVAILABLE=true
    fi
fi

# Logging function that works with or without bashio
log_info() {
    if [ "$BASHIO_AVAILABLE" = true ]; then
        bashio::log.info "$1"
    else
        echo "[INFO] $1"
    fi
}

# Config function that works with or without bashio
get_config() {
    local key="$1"
    local default="$2"
    
    if [ "$BASHIO_AVAILABLE" = true ]; then
        bashio::config "$key" "$default" 2>/dev/null || echo "$default"
    else
        # Fallback to direct JSON reading
        if [ -f "/data/options.json" ]; then
            jq -r ".$key // \"$default\"" /data/options.json 2>/dev/null || echo "$default"
        else
            echo "$default"
        fi
    fi
}

# Check if config has value
has_config_value() {
    local key="$1"
    
    if [ "$BASHIO_AVAILABLE" = true ]; then
        bashio::config.has_value "$key" 2>/dev/null
    else
        if [ -f "/data/options.json" ]; then
            local value=$(jq -r ".$key // null" /data/options.json 2>/dev/null)
            [ "$value" != "null" ] && [ "$value" != "" ]
        else
            false
        fi
    fi
}

log_info "🏠 Starting Gree MQTT Bridge Add-on..."

if [ "$BASHIO_AVAILABLE" = true ]; then
    log_info "Using bashio for configuration management"
else
    log_info "Bashio not available, using fallback configuration reading"
fi

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

    if has_config_value 'network'; then
        if [ "$BASHIO_AVAILABLE" = true ]; then
            export NETWORK=$(
                bashio::config 'network' \
                    | jq -r '.[].ip' \
                    | paste -sd, -
            )
        else
            export NETWORK=$(
                jq -r '.network[]?.ip // empty' /data/options.json 2>/dev/null \
                    | paste -sd, - || echo ""
            )
        fi
    fi

    if has_config_value 'subnet'; then
        export SUBNET=$(get_config 'subnet' '')
    fi

    if has_config_value 'udp_port'; then
        export UDP_PORT=$(get_config 'udp_port' '')
    fi

    log_info "Configuration loaded:"
    log_info "- MQTT Broker: ${MQTT_BROKER}"
    log_info "- MQTT Port: ${MQTT_PORT}"
    log_info "- MQTT User: ${MQTT_USER}"
    log_info "- MQTT Topic: ${MQTT_TOPIC}"
    log_info "- Update Interval: ${UPDATE_INTERVAL}s"
    log_info "- Adaptive Polling Timeout: ${ADAPTIVE_POLLING_TIMEOUT}s"
    log_info "- Fast Polling Interval: ${ADAPTIVE_FAST_INTERVAL}s"
    log_info "- MQTT Workers: ${MQTT_MESSAGE_WORKERS}"
    log_info "- Immediate Response Timeout: ${IMMEDIATE_RESPONSE_TIMEOUT}s"

    if [ -n "${NETWORK:-}" ]; then
        log_info "- Device Network: ${NETWORK}"
    else
        log_info "- Device Discovery: Auto-scan enabled"
    fi

    if [ -n "${SUBNET:-}" ]; then
        log_info "- Subnet: ${SUBNET}"
    fi

    if [ -n "${UDP_PORT:-}" ]; then
        log_info "- UDP Port: ${UDP_PORT}"
    fi
}

run_application() {
    log_info "🚀 Launching GreeMQTT..."
    exec uv run GreeMQTT
}

main() {
    setup_environment
    run_application
}

trap 'log_info "🛑 Shutting down Gree MQTT Bridge..."; exit 0' SIGTERM SIGINT

main "$@"