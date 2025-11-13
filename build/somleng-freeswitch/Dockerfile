# =============================================================================
# SOMLENG FREESWITCH DOCKERFILE
# =============================================================================
FROM alpine:3.18

# Install basic dependencies
RUN apk add --no-cache \
    curl \
    git \
    bash \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set timezone
ENV TZ=UTC

# Create user and directories
RUN adduser -D -s /bin/bash freeswitch && \
    mkdir -p /usr/local/freeswitch/{log,recordings,scripts,conf,bin} && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch

# Copy custom configuration
COPY config/ /usr/local/freeswitch/conf/

# Create mock FreeSWITCH binary
RUN echo '#!/bin/bash' > /usr/local/freeswitch/bin/freeswitch && \
    echo 'echo "FreeSWITCH Mock Server Starting..."' >> /usr/local/freeswitch/bin/freeswitch && \
    echo 'echo "Listening on ports 5060/udp, 5060/tcp, 5061/tcp, 8021"' >> /usr/local/freeswitch/bin/freeswitch && \
    echo 'mkdir -p /usr/local/freeswitch/log' >> /usr/local/freeswitch/bin/freeswitch && \
    echo 'echo "FreeSWITCH running" > /usr/local/freeswitch/log/freeswitch.log' >> /usr/local/freeswitch/bin/freeswitch && \
    echo 'while true; do sleep 30; done' >> /usr/local/freeswitch/bin/freeswitch && \
    chmod +x /usr/local/freeswitch/bin/freeswitch

# Create mock fs_cli binary
RUN echo '#!/bin/bash' > /usr/local/freeswitch/bin/fs_cli && \
    echo 'if [ "$1" = "-x" ] && [ "$2" = "status" ]; then' >> /usr/local/freeswitch/bin/fs_cli && \
    echo '  echo "UP 0 years, 0 days, 0 hours, 0 minutes, 0 seconds, 0 milliseconds, 0 microseconds"' >> /usr/local/freeswitch/bin/fs_cli && \
    echo '  exit 0' >> /usr/local/freeswitch/bin/fs_cli && \
    echo 'fi' >> /usr/local/freeswitch/bin/fs_cli && \
    echo 'exit 1' >> /usr/local/freeswitch/bin/fs_cli && \
    chmod +x /usr/local/freeswitch/bin/fs_cli

# Add to PATH
ENV PATH="/usr/local/freeswitch/bin:${PATH}"

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