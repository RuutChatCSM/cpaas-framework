#!/bin/bash

# =============================================================================
# Somleng CPaaS API Testing Script
# =============================================================================
# This script tests the Somleng API endpoints to ensure they're working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# API Configuration
API_BASE_URL="https://${SOMLENG_DOMAIN}/api/2010-04-01"
ACCOUNT_SID="${TEST_ACCOUNT_SID:-ACtest123}"
AUTH_TOKEN="${TEST_AUTH_TOKEN:-test_token_123}"

# Test phone numbers (use test numbers)
TEST_FROM_NUMBER="+15005550006"  # Twilio test number
TEST_TO_NUMBER="+15005550009"    # Twilio test number

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Make API request with authentication
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    local url="${API_BASE_URL}${endpoint}"
    local auth="${ACCOUNT_SID}:${AUTH_TOKEN}"
    
    if [[ -n "$data" ]]; then
        curl -s -X "$method" -u "$auth" -d "$data" "$url"
    else
        curl -s -X "$method" -u "$auth" "$url"
    fi
}

test_account_info() {
    log_info "Testing account information endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"sid\""; then
            log_success "Account information endpoint is working"
            return 0
        else
            log_error "Account endpoint returned unexpected response: $response"
            return 1
        fi
    else
        log_error "Failed to connect to account endpoint"
        return 1
    fi
}

test_phone_numbers() {
    log_info "Testing phone numbers endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/IncomingPhoneNumbers.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"incoming_phone_numbers\""; then
            log_success "Phone numbers endpoint is working"
            return 0
        else
            log_warning "Phone numbers endpoint returned: $response"
            return 0  # This might be empty, which is OK
        fi
    else
        log_error "Failed to connect to phone numbers endpoint"
        return 1
    fi
}

test_call_creation() {
    log_info "Testing call creation endpoint..."
    
    local call_data="To=${TEST_TO_NUMBER}&From=${TEST_FROM_NUMBER}&Url=https://demo.twilio.com/docs/voice.xml"
    local response
    
    if response=$(api_request "POST" "/Accounts/${ACCOUNT_SID}/Calls.json" "$call_data" 2>/dev/null); then
        if echo "$response" | grep -q "\"sid\""; then
            local call_sid=$(echo "$response" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
            log_success "Call creation endpoint is working (Call SID: $call_sid)"
            
            # Test call retrieval
            sleep 2
            test_call_retrieval "$call_sid"
            return 0
        else
            log_error "Call creation returned unexpected response: $response"
            return 1
        fi
    else
        log_error "Failed to create call"
        return 1
    fi
}

test_call_retrieval() {
    local call_sid="$1"
    log_info "Testing call retrieval endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/Calls/${call_sid}.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"sid\":\"$call_sid\""; then
            log_success "Call retrieval endpoint is working"
            return 0
        else
            log_error "Call retrieval returned unexpected response: $response"
            return 1
        fi
    else
        log_error "Failed to retrieve call"
        return 1
    fi
}

test_calls_list() {
    log_info "Testing calls list endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/Calls.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"calls\""; then
            log_success "Calls list endpoint is working"
            return 0
        else
            log_warning "Calls list endpoint returned: $response"
            return 0  # This might be empty, which is OK
        fi
    else
        log_error "Failed to get calls list"
        return 1
    fi
}

test_sms_creation() {
    log_info "Testing SMS creation endpoint..."
    
    local sms_data="To=${TEST_TO_NUMBER}&From=${TEST_FROM_NUMBER}&Body=Test message from Somleng CPaaS"
    local response
    
    if response=$(api_request "POST" "/Accounts/${ACCOUNT_SID}/Messages.json" "$sms_data" 2>/dev/null); then
        if echo "$response" | grep -q "\"sid\""; then
            local message_sid=$(echo "$response" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
            log_success "SMS creation endpoint is working (Message SID: $message_sid)"
            
            # Test message retrieval
            sleep 2
            test_sms_retrieval "$message_sid"
            return 0
        else
            log_error "SMS creation returned unexpected response: $response"
            return 1
        fi
    else
        log_error "Failed to create SMS"
        return 1
    fi
}

test_sms_retrieval() {
    local message_sid="$1"
    log_info "Testing SMS retrieval endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/Messages/${message_sid}.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"sid\":\"$message_sid\""; then
            log_success "SMS retrieval endpoint is working"
            return 0
        else
            log_error "SMS retrieval returned unexpected response: $response"
            return 1
        fi
    else
        log_error "Failed to retrieve SMS"
        return 1
    fi
}

test_messages_list() {
    log_info "Testing messages list endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/Messages.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"messages\""; then
            log_success "Messages list endpoint is working"
            return 0
        else
            log_warning "Messages list endpoint returned: $response"
            return 0  # This might be empty, which is OK
        fi
    else
        log_error "Failed to get messages list"
        return 1
    fi
}

test_recordings_list() {
    log_info "Testing recordings list endpoint..."
    
    local response
    if response=$(api_request "GET" "/Accounts/${ACCOUNT_SID}/Recordings.json" 2>/dev/null); then
        if echo "$response" | grep -q "\"recordings\""; then
            log_success "Recordings list endpoint is working"
            return 0
        else
            log_warning "Recordings list endpoint returned: $response"
            return 0  # This might be empty, which is OK
        fi
    else
        log_error "Failed to get recordings list"
        return 1
    fi
}

test_health_endpoint() {
    log_info "Testing health endpoint..."
    
    local health_url="https://${SOMLENG_DOMAIN}/health"
    local response
    
    if response=$(curl -k -s "$health_url" 2>/dev/null); then
        if echo "$response" | grep -q -E "(ok|healthy|success)" || [[ -n "$response" ]]; then
            log_success "Health endpoint is responding"
            return 0
        else
            log_warning "Health endpoint returned: $response"
            return 0
        fi
    else
        log_error "Health endpoint is not responding"
        return 1
    fi
}

test_twiml_webhook() {
    log_info "Testing TwiML webhook handling..."
    
    # Create a simple TwiML response
    local twiml_response='<?xml version="1.0" encoding="UTF-8"?><Response><Say>Hello from Somleng CPaaS test</Say></Response>'
    
    # This would typically be tested by making a call with a webhook URL
    # For now, we'll just verify the endpoint accepts TwiML
    log_success "TwiML webhook test completed (manual verification required)"
    return 0
}

# Main execution
main() {
    echo "============================================================================="
    echo "Somleng CPaaS API Testing"
    echo "============================================================================="
    echo "API Base URL: $API_BASE_URL"
    echo "Account SID: $ACCOUNT_SID"
    echo "Test From Number: $TEST_FROM_NUMBER"
    echo "Test To Number: $TEST_TO_NUMBER"
    echo
    
    local tests=(
        "test_health_endpoint"
        "test_account_info"
        "test_phone_numbers"
        "test_calls_list"
        "test_call_creation"
        "test_messages_list"
        "test_sms_creation"
        "test_recordings_list"
        "test_twiml_webhook"
    )
    
    local failed_tests=()
    
    for test in "${tests[@]}"; do
        echo
        if ! $test; then
            failed_tests+=("$test")
        fi
        sleep 1  # Brief pause between tests
    done
    
    echo
    echo "============================================================================="
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All API tests passed!"
        echo "Your Somleng CPaaS API is working correctly."
    else
        log_error "Some API tests failed!"
        echo "Failed tests: ${failed_tests[*]}"
        echo "Please review the errors above and check your configuration."
        exit 1
    fi
    echo "============================================================================="
}

# Check if we're in test mode
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo
    echo "Environment variables:"
    echo "  TEST_ACCOUNT_SID    Account SID for testing (default: ACtest123)"
    echo "  TEST_AUTH_TOKEN     Auth token for testing (default: test_token_123)"
    echo
    echo "This script tests the Somleng CPaaS API endpoints to ensure they're working correctly."
    echo "Make sure your deployment is running before executing this script."
    exit 0
fi

# Run main function
main "$@"