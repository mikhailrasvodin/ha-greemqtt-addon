#!/usr/bin/with-contenv bashio

set -e

# Funkcja do generowania konfiguracji
generate_config() {
    local config_file="/app/config.yaml"
    
    bashio::log.info "Generowanie konfiguracji GreeMQTT..."
    
    # Pobieramy konfigurację z Home Assistant
    local mqtt_host mqtt_port mqtt_user mqtt_pass mqtt_topic
    local discovery_timeout update_interval web_interface web_port log_level
    
    mqtt_host=$(bashio::config 'mqtt_host')
    mqtt_port=$(bashio::config 'mqtt_port')
    mqtt_user=$(bashio::config 'mqtt_username')
    mqtt_pass=$(bashio::config 'mqtt_password')
    mqtt_topic=$(bashio::config 'mqtt_topic')
    discovery_timeout=$(bashio::config 'discovery_timeout')
    update_interval=$(bashio::config 'update_interval')
    web_interface=$(bashio::config 'web_interface')
    web_port=$(bashio::config 'web_port')
    log_level=$(bashio::config 'log_level')
    
    # Generujemy plik konfiguracyjny
    cat > "${config_file}" << EOF
mqtt:
  host: "${mqtt_host}"
  port: ${mqtt_port}
  username: "${mqtt_user}"
  password: "${mqtt_pass}"
  topic: "${mqtt_topic}"

gree:
  discovery_timeout: ${discovery_timeout}
  update_interval: ${update_interval}

web:
  enabled: ${web_interface}
  port: ${web_port}

logging:
  level: "${log_level}"

devices:
EOF

    # Dodajemy urządzenia z konfiguracji
    if bashio::config.has_value 'devices'; then
        bashio::config 'devices' | jq -r '.[] | @base64' | while read -r device; do
            local device_json
            device_json=$(echo "${device}" | base64 -d)
            local ip name mac
            ip=$(echo "${device_json}" | jq -r '.ip')
            name=$(echo "${device_json}" | jq -r '.name // empty')
            mac=$(echo "${device_json}" | jq -r '.mac // empty')
            
            echo "  - ip: \"${ip}\"" >> "${config_file}"
            if [[ -n "${name}" ]]; then
                echo "    name: \"${name}\"" >> "${config_file}"
            fi
            if [[ -n "${mac}" ]]; then
                echo "    mac: \"${mac}\"" >> "${config_file}"
            fi
        done
    fi
    
    bashio::log.info "Konfiguracja wygenerowana pomyślnie"
}

# Funkcja sprawdzania połączenia MQTT
check_mqtt() {
    local mqtt_host mqtt_port
    mqtt_host=$(bashio::config 'mqtt_host')
    mqtt_port=$(bashio::config 'mqtt_port')
    
    bashio::log.info "Sprawdzanie połączenia z MQTT broker: ${mqtt_host}:${mqtt_port}"
    
    if ! nc -z "${mqtt_host}" "${mqtt_port}"; then
        bashio::log.error "Nie można połączyć się z MQTT broker!"
        bashio::log.error "Sprawdź czy broker MQTT jest uruchomiony i dostępny"
        exit 1
    fi
    
    bashio::log.info "Połączenie z MQTT broker OK"
}

# Główna funkcja
main() {
    bashio::log.info "Uruchamianie Gree MQTT Bridge..."
    
    # Sprawdzamy połączenie MQTT
    check_mqtt
    
    # Generujemy konfigurację
    generate_config
    
    # Ustawiamy zmienne środowiskowe jeśli potrzebne
    export CONFIG_FILE="/app/config.yaml"
    
    # Wyświetlamy informacje o konfiguracji
    bashio::log.info "Konfiguracja:"
    bashio::log.info "- MQTT Host: $(bashio::config 'mqtt_host')"
    bashio::log.info "- MQTT Port: $(bashio::config 'mqtt_port')"
    bashio::log.info "- MQTT Topic: $(bashio::config 'mqtt_topic')"
    bashio::log.info "- Discovery Timeout: $(bashio::config 'discovery_timeout')s"
    bashio::log.info "- Update Interval: $(bashio::config 'update_interval')s"
    bashio::log.info "- Web Interface: $(bashio::config 'web_interface')"
    
    if bashio::config.true 'web_interface'; then
        bashio::log.info "- Web Port: $(bashio::config 'web_port')"
        bashio::log.info "Web interface będzie dostępny na porcie $(bashio::config 'web_port')"
    fi
    
    # Uruchamiamy GreeMQTT
    bashio::log.info "Uruchamianie GreeMQTT..."
    exec python3 /app/main.py
}

# Uruchamiamy główną funkcję
main "$@"