# =============================================================================
# SOMLENG WEB APPLICATION DOCKERFILE
# =============================================================================
FROM ruby:3.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    libxml2-dev \
    libxslt-dev \
    postgresql-dev \
    git \
    curl \
    nodejs \
    npm \
    ffmpeg \
    sox \
    lame

# Set application directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile* ./

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3

# Copy application code
COPY . .

# Precompile assets (if needed)
RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bundle exec rails assets:precompile 2>/dev/null || true

# Set environment
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]