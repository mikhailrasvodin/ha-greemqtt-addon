#!/usr/bin/with-contenv bashio

set -e

bashio::log.info "Starting Gree MQTT Bridge..."

# Funkcja sprawdzania MQTT
check_mqtt_connection() {
    local mqtt_host mqtt_port
    mqtt_host=$(bashio::config 'mqtt_host')
    mqtt_port=$(bashio::config 'mqtt_port')
    
    bashio::log.info "Checking MQTT connection to ${mqtt_host}:${mqtt_port}..."
    
    local timeout=60
    local count=0
    
    while [ $count -lt $timeout ]; do
        if nc -z "${mqtt_host}" "${mqtt_port}" 2>/dev/null; then
            bashio::log.info "✅ MQTT broker is accessible"
            return 0
        fi
        
        bashio::log.warning "⏳ MQTT broker not ready, waiting... (${count}/${timeout}s)"
        sleep 2
        count=$((count + 2))
    done
    
    bashio::log.error "❌ Cannot connect to MQTT broker at ${mqtt_host}:${mqtt_port}"
    bashio::log.error "Make sure Mosquitto broker addon is running"
    exit 1
}

# Funkcja ustawiania zmiennych środowiskowych
setup_environment() {
    # Pobieramy konfigurację z Home Assistant
    local mqtt_host mqtt_port mqtt_user mqtt_pass mqtt_topic
    local update_interval discovery_timeout log_level
    local adaptive_polling_timeout adaptive_fast_interval mqtt_workers immediate_response_timeout
    
    mqtt_host=$(bashio::config 'mqtt_host' 'core-mosquitto')
    mqtt_port=$(bashio::config 'mqtt_port' '1883')
    mqtt_user=$(bashio::config 'mqtt_username' '')
    mqtt_pass=$(bashio::config 'mqtt_password' '')
    mqtt_topic=$(bashio::config 'mqtt_topic' 'gree')
    update_interval=$(bashio::config 'update_interval' '3')
    log_level=$(bashio::config 'log_level' 'INFO')
    
    # Zaawansowane ustawienia
    adaptive_polling_timeout=$(bashio::config 'adaptive_polling_timeout' '45')
    adaptive_fast_interval=$(bashio::config 'adaptive_fast_interval' '0.8')
    mqtt_workers=$(bashio::config 'mqtt_message_workers' '3')
    immediate_response_timeout=$(bashio::config 'immediate_response_timeout' '5')
    
    # Ustawiamy zmienne środowiskowe zgodnie z dokumentacją GreeMQTT
    export MQTT_BROKER="${mqtt_host}"
    export MQTT_PORT="${mqtt_port}"
    export MQTT_USER="${mqtt_user}"
    export MQTT_PASSWORD="${mqtt_pass}"
    export MQTT_TOPIC="${mqtt_topic}"
    export UPDATE_INTERVAL="${update_interval}"
    export ADAPTIVE_POLLING_TIMEOUT="${adaptive_polling_timeout}"
    export ADAPTIVE_FAST_INTERVAL="${adaptive_fast_interval}"
    export MQTT_MESSAGE_WORKERS="${mqtt_workers}"
    export IMMEDIATE_RESPONSE_TIMEOUT="${immediate_response_timeout}"
    
    # Opcjonalne ustawienia sieciowe
    if bashio::config.has_value 'network'; then
        local network_list=""
        bashio::config 'network' | jq -r '.[] | @base64' | while IFS= read -r device; do
            local device_json ip
            device_json=$(echo "${device}" | base64 -d)
            ip=$(echo "${device_json}" | jq -r '.ip')
            if [ -n "${network_list}" ]; then
                network_list="${network_list},${ip}"
            else
                network_list="${ip}"
            fi
        done
        export NETWORK="${network_list}"
    fi
    
    if bashio::config.has_value 'subnet'; then
        export SUBNET=$(bashio::config 'subnet')
    fi
    
    if bashio::config.has_value 'udp_port'; then
        export UDP_PORT=$(bashio::config 'udp_port')
    fi
    
    # Logujemy konfigurację (bez haseł)
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
}

# Funkcja uruchomienia aplikacji
run_application() {
    bashio::log.info "🚀 Starting GreeMQTT application..."
    
    cd /app
    
    # Uruchamiamy aplikację zgodnie z dokumentacją
    exec python -m GreeMQTT
}

# Główna funkcja
main() {
    bashio::log.info "🏠 Gree MQTT Bridge Add-on starting..."
    
    # Ustawiamy zmienne środowiskowe
    setup_environment
    
    # Sprawdzamy połączenie MQTT
    check_mqtt_connection
    
    # Wyświetlamy informacje o funkcjach
    bashio::log.info "🔧 Features enabled:"
    bashio::log.info "- Fast Response System (sub-second response times)"
    bashio::log.info "- Adaptive Polling (automatic frequency adjustment)"
    bashio::log.info "- Concurrent Processing (${MQTT_MESSAGE_WORKERS} workers)"
    bashio::log.info "- Auto Device Discovery"
    bashio::log.info "- Performance Monitoring"
    
    # Uruchamiamy aplikację
    run_application
}

# Obsługa sygnałów
trap 'bashio::log.info "🛑 Shutting down Gree MQTT Bridge..."; exit 0' SIGTERM SIGINT

# Uruchamiamy główną funkcję
main "$@"