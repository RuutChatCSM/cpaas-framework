# =============================================================================
# SOMLENG FREESWITCH DOCKERFILE
# =============================================================================
FROM alpine:3.18

# Install FreeSWITCH and dependencies
RUN apk add --no-cache \
    freeswitch \
    freeswitch-sample-config \
    freeswitch-lang-en \
    freeswitch-mod-sofia \
    freeswitch-mod-json-cdr \
    freeswitch-mod-commands \
    freeswitch-mod-console \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-event-socket \
    freeswitch-mod-local-stream \
    freeswitch-mod-xml-cdr \
    freeswitch-mod-pgsql \
    curl \
    git \
    bash \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set timezone
ENV TZ=UTC

# Create directories
RUN mkdir -p /usr/local/freeswitch/{log,recordings,scripts,conf}

# Copy custom configuration
COPY freeswitch/config/ /usr/local/freeswitch/conf/

# Set permissions
RUN chown -R freeswitch:freeswitch /usr/local/freeswitch

# Expose ports
EXPOSE 5060/udp 5060/tcp 5061/tcp 8021 16384-32767/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD fs_cli -x "status" || exit 1

# Start FreeSWITCH
USER freeswitch
CMD ["freeswitch"]