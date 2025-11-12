# Somleng CPaaS API Guide

This guide covers the Somleng API, which is fully compatible with Twilio's REST API, allowing you to easily migrate from Twilio or integrate with existing Twilio-based applications.

## API Overview

Somleng provides a RESTful API that mirrors Twilio's API structure, making it a drop-in replacement for most Twilio use cases.

### Base URL
```
https://yourdomain.com/api/2010-04-01
```

### Authentication
All API requests use HTTP Basic Authentication with your Account SID as the username and Auth Token as the password.

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx.json \
  -u "ACxxxx:your_auth_token"
```

## Account Management

### Get Account Information

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx.json \
  -u "ACxxxx:your_auth_token"
```

Response:
```json
{
  "sid": "ACxxxx",
  "friendly_name": "My Account",
  "status": "active",
  "type": "Full",
  "date_created": "2024-01-01T00:00:00Z",
  "date_updated": "2024-01-01T00:00:00Z",
  "auth_token": "your_auth_token",
  "uri": "/2010-04-01/Accounts/ACxxxx.json"
}
```

### Create Subaccount

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts.json \
  -u "ACxxxx:your_auth_token" \
  -d "FriendlyName=My Subaccount"
```

## Voice Calls

### Make an Outbound Call

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls.json \
  -u "ACxxxx:your_auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Url=https://example.com/voice.xml"
```

Parameters:
- `To`: Destination phone number (E.164 format)
- `From`: Your Somleng phone number
- `Url`: TwiML URL for call instructions
- `Method`: HTTP method for TwiML URL (GET or POST)
- `StatusCallback`: URL for call status updates
- `StatusCallbackMethod`: HTTP method for status callbacks
- `Timeout`: Timeout in seconds (default: 60)

Response:
```json
{
  "sid": "CAxxxx",
  "account_sid": "ACxxxx",
  "to": "+1234567890",
  "from": "+0987654321",
  "status": "queued",
  "start_time": null,
  "end_time": null,
  "duration": null,
  "price": null,
  "direction": "outbound-api",
  "answered_by": null,
  "forwarded_from": null,
  "caller_name": null,
  "uri": "/2010-04-01/Accounts/ACxxxx/Calls/CAxxxx.json",
  "date_created": "2024-01-01T00:00:00Z",
  "date_updated": "2024-01-01T00:00:00Z"
}
```

### Get Call Details

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls/CAxxxx.json \
  -u "ACxxxx:your_auth_token"
```

### List Calls

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls.json \
  -u "ACxxxx:your_auth_token"
```

Query parameters:
- `To`: Filter by destination number
- `From`: Filter by source number
- `Status`: Filter by call status
- `StartTime`: Filter by start time
- `EndTime`: Filter by end time
- `PageSize`: Number of results per page (max 1000)
- `Page`: Page number

### Modify Live Call

```bash
# Redirect call to new TwiML
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls/CAxxxx.json \
  -u "ACxxxx:your_auth_token" \
  -d "Url=https://example.com/new-instructions.xml"

# Hangup call
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls/CAxxxx.json \
  -u "ACxxxx:your_auth_token" \
  -d "Status=completed"
```

## SMS Messages

### Send SMS

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Messages.json \
  -u "ACxxxx:your_auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Body=Hello from Somleng!"
```

Parameters:
- `To`: Destination phone number
- `From`: Your Somleng phone number
- `Body`: Message text (max 1600 characters)
- `StatusCallback`: URL for delivery status updates

Response:
```json
{
  "sid": "SMxxxx",
  "account_sid": "ACxxxx",
  "to": "+1234567890",
  "from": "+0987654321",
  "body": "Hello from Somleng!",
  "status": "queued",
  "direction": "outbound-api",
  "price": null,
  "price_unit": "USD",
  "error_code": null,
  "error_message": null,
  "uri": "/2010-04-01/Accounts/ACxxxx/Messages/SMxxxx.json",
  "date_created": "2024-01-01T00:00:00Z",
  "date_updated": "2024-01-01T00:00:00Z",
  "date_sent": null
}
```

### Get Message Details

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Messages/SMxxxx.json \
  -u "ACxxxx:your_auth_token"
```

### List Messages

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Messages.json \
  -u "ACxxxx:your_auth_token"
```

## Phone Numbers

### List Phone Numbers

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/IncomingPhoneNumbers.json \
  -u "ACxxxx:your_auth_token"
```

### Get Phone Number Details

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/IncomingPhoneNumbers/PNxxxx.json \
  -u "ACxxxx:your_auth_token"
```

### Update Phone Number

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/IncomingPhoneNumbers/PNxxxx.json \
  -u "ACxxxx:your_auth_token" \
  -d "VoiceUrl=https://example.com/voice.xml" \
  -d "SmsUrl=https://example.com/sms.xml"
```

## Recordings

### List Recordings

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Recordings.json \
  -u "ACxxxx:your_auth_token"
```

### Get Recording Details

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Recordings/RExxxx.json \
  -u "ACxxxx:your_auth_token"
```

### Download Recording

```bash
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Recordings/RExxxx.wav \
  -u "ACxxxx:your_auth_token" \
  -o recording.wav
```

### Delete Recording

```bash
curl -X DELETE https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Recordings/RExxxx.json \
  -u "ACxxxx:your_auth_token"
```

## TwiML (Twilio Markup Language)

Somleng supports TwiML for controlling call and SMS flows.

### Voice TwiML

#### Basic Voice Response

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="alice">Welcome to Somleng CPaaS!</Say>
    <Play>https://example.com/welcome.mp3</Play>
</Response>
```

#### Interactive Voice Response (IVR)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Gather action="/handle-key" numDigits="1" timeout="10">
        <Say>Press 1 for sales, 2 for support, or 0 for operator</Say>
    </Gather>
    <Say>We didn't receive any input. Goodbye!</Say>
    <Hangup/>
</Response>
```

#### Call Forwarding

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say>Connecting you now</Say>
    <Dial timeout="30" callerId="+0987654321">
        <Number>+1234567890</Number>
    </Dial>
    <Say>The call could not be completed</Say>
</Response>
```

#### Conference Call

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say>Joining conference room</Say>
    <Dial>
        <Conference>MyConference</Conference>
    </Dial>
</Response>
```

#### Call Recording

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say>This call will be recorded</Say>
    <Record action="/handle-recording" maxLength="60" finishOnKey="#"/>
    <Say>Thank you for your message</Say>
</Response>
```

### SMS TwiML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>Thank you for your message! We'll get back to you soon.</Message>
</Response>
```

## Webhooks

Somleng sends HTTP requests to your application for various events.

### Voice Webhooks

#### Incoming Call Webhook

When someone calls your Somleng number:

```
POST /voice HTTP/1.1
Content-Type: application/x-www-form-urlencoded

CallSid=CAxxxx&
AccountSid=ACxxxx&
From=%2B1234567890&
To=%2B0987654321&
CallStatus=ringing&
ApiVersion=2010-04-01&
Direction=inbound&
ForwardedFrom=&
CallerName=
```

#### Call Status Webhook

Updates on call progress:

```
POST /status HTTP/1.1
Content-Type: application/x-www-form-urlencoded

CallSid=CAxxxx&
AccountSid=ACxxxx&
From=%2B1234567890&
To=%2B0987654321&
CallStatus=completed&
CallDuration=45&
RecordingUrl=https://yourdomain.com/recording.wav
```

### SMS Webhooks

#### Incoming SMS Webhook

```
POST /sms HTTP/1.1
Content-Type: application/x-www-form-urlencoded

MessageSid=SMxxxx&
AccountSid=ACxxxx&
From=%2B1234567890&
To=%2B0987654321&
Body=Hello%20Somleng&
NumMedia=0
```

#### SMS Status Webhook

```
POST /sms-status HTTP/1.1
Content-Type: application/x-www-form-urlencoded

MessageSid=SMxxxx&
MessageStatus=delivered&
To=%2B1234567890&
From=%2B0987654321&
AccountSid=ACxxxx
```

## Error Handling

### HTTP Status Codes

- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Invalid credentials
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

### Error Response Format

```json
{
  "code": 20003,
  "message": "Authentication Error - invalid username",
  "more_info": "https://docs.somleng.org/errors/20003",
  "status": 401
}
```

### Common Error Codes

- `20003`: Authentication Error
- `21211`: Invalid 'To' Phone Number
- `21212`: Invalid 'From' Phone Number
- `21602`: Message body is required
- `21610`: Message cannot be sent to the destination number

## Rate Limiting

Somleng implements rate limiting to ensure fair usage:

- **API Requests**: 1000 requests per hour per account
- **SMS Messages**: 100 messages per hour per phone number
- **Voice Calls**: 100 calls per hour per phone number

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## SDKs and Libraries

### Official SDKs

You can use Twilio's official SDKs with Somleng by changing the base URL:

#### Node.js

```javascript
const twilio = require('twilio');

const client = twilio(accountSid, authToken, {
  baseUrl: 'https://yourdomain.com'
});

// Make a call
client.calls.create({
  to: '+1234567890',
  from: '+0987654321',
  url: 'https://example.com/voice.xml'
});
```

#### Python

```python
from twilio.rest import Client

client = Client(account_sid, auth_token)
client.base_uri = 'https://yourdomain.com'

# Send SMS
message = client.messages.create(
    to='+1234567890',
    from_='+0987654321',
    body='Hello from Somleng!'
)
```

#### Ruby

```ruby
require 'twilio-ruby'

@client = Twilio::REST::Client.new(account_sid, auth_token)
@client.base_uri = 'https://yourdomain.com'

# Make a call
call = @client.calls.create(
  to: '+1234567890',
  from: '+0987654321',
  url: 'https://example.com/voice.xml'
)
```

#### PHP

```php
require_once 'vendor/autoload.php';
use Twilio\Rest\Client;

$client = new Client($account_sid, $auth_token);
$client->setBaseUri('https://yourdomain.com');

// Send SMS
$message = $client->messages->create(
    '+1234567890',
    [
        'from' => '+0987654321',
        'body' => 'Hello from Somleng!'
    ]
);
```

## Best Practices

### Security

1. **Use HTTPS**: Always use HTTPS for webhook URLs
2. **Validate Webhooks**: Verify webhook signatures
3. **Secure Credentials**: Store API credentials securely
4. **Rate Limiting**: Implement your own rate limiting

### Performance

1. **Async Processing**: Handle webhooks asynchronously
2. **Caching**: Cache frequently accessed data
3. **Connection Pooling**: Reuse HTTP connections
4. **Pagination**: Use pagination for large result sets

### Error Handling

1. **Retry Logic**: Implement exponential backoff for retries
2. **Logging**: Log all API interactions
3. **Monitoring**: Monitor API usage and errors
4. **Fallbacks**: Implement fallback mechanisms

### Testing

1. **Sandbox Mode**: Use test credentials for development
2. **Webhook Testing**: Use tools like ngrok for local testing
3. **Unit Tests**: Write comprehensive unit tests
4. **Integration Tests**: Test end-to-end workflows

## Migration from Twilio

### Step 1: Update Base URL

Change your API base URL from Twilio to your Somleng instance:

```
# From
https://api.twilio.com/2010-04-01

# To
https://yourdomain.com/api/2010-04-01
```

### Step 2: Update Credentials

Replace your Twilio Account SID and Auth Token with your Somleng credentials.

### Step 3: Test Functionality

Test all your existing functionality to ensure compatibility.

### Step 4: Update Webhooks

Update your webhook URLs to point to your new endpoints if needed.

### Step 5: Monitor and Optimize

Monitor your application performance and optimize as needed.

## Support and Resources

### Documentation
- [Somleng API Documentation](https://docs.somleng.org/api)
- [TwiML Reference](https://docs.somleng.org/twiml)

### Community
- GitHub Issues
- Community Forums
- Stack Overflow (tag: somleng)

### Professional Support
- Commercial support plans
- Professional services
- Custom development

---

This API guide provides comprehensive coverage of the Somleng API. For the most up-to-date information, refer to the official Somleng documentation.