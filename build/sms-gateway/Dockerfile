# =============================================================================
# SMS GATEWAY DOCKERFILE
# =============================================================================
FROM ruby:3.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    curl

# Set application directory
WORKDIR /app

# Copy Gemfile (create minimal one for SMS gateway)
RUN echo 'source "https://rubygems.org"' > Gemfile && \
    echo 'gem "sinatra"' >> Gemfile && \
    echo 'gem "httparty"' >> Gemfile && \
    echo 'gem "pg"' >> Gemfile && \
    echo 'gem "redis"' >> Gemfile

# Copy Gemfile.lock
COPY <<EOF >Gemfile.lock
GEM
  remote: https://rubygems.org/
  specs:
    httparty (0.21.0)
      mini_mime (>= 1.0.0)
      multi_xml (>= 0.5.2)
    mini_mime (1.1.5)
    multi_xml (0.6.0)
    pg (1.5.3)
    rack (3.0.8)
    rackup (2.1.0)
      rack
    redis (5.0.7)
    sinatra (3.1.0)
      rack (~> 2.2, >= 2.2.4)
      rackup (~> 2.0)
      tilt (~> 2.0)
    tilt (2.1.0)

PLATFORMS
  ruby
  x86_64-linux-musl

DEPENDENCIES
  httparty
  pg
  redis
  sinatra

RUBY VERSION
   ruby 3.2.0p0

BUNDLED WITH
   2.4.1
EOF

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3

# Create minimal SMS gateway application
COPY <<EOF >app.rb
require 'sinatra'
require 'httparty'
require 'pg'
require 'redis'

set :bind, '0.0.0.0'
set :port, 3002

configure do
  # Configure database connection
  db_url = ENV['DATABASE_URL'] || 'postgresql://localhost/sms_gateway'
  # Configure Redis connection
  redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
end

# Health check endpoint
get '/health' do
  content_type :json
  { status: 'ok', service: 'sms-gateway' }.to_json
end

# SMS receiving endpoint
post '/sms/receive' do
  content_type :json
  # Process incoming SMS
  { status: 'received' }.to_json
end

# SMS sending endpoint
post '/sms/send' do
  content_type :json
  # Process outgoing SMS
  { status: 'sent' }.to_json
end

# Start Sinatra application
EOF

# Create minimal config.ru
COPY <<EOF >config.ru
require './app'
run Sinatra::Application
EOF

# Expose port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3002/health || exit 1

# Start command
CMD ["ruby", "app.rb"]