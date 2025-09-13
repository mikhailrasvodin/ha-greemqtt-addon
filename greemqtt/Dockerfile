FROM monteship/greemqtt:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      jq bash \
    && rm -rf /var/lib/apt/lists/*

# Show original file info
RUN echo "=== BEFORE REPLACEMENT ===" && \
    head -5 /app/GreeMQTT/__main__.py

# Copy the fixed main file to override the original
COPY __main__.py /app/GreeMQTT/__main__.py

# Show replaced file info
RUN echo "=== AFTER REPLACEMENT ===" && \
    head -10 /app/GreeMQTT/__main__.py && \
    echo "=== CHECKING FOR CUSTOM MARKER ===" && \
    grep -q "USING CUSTOM ERROR-RESISTANT VERSION" /app/GreeMQTT/__main__.py && \
    echo "✅ Custom file detected!" || echo "❌ Original file still there!"

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]