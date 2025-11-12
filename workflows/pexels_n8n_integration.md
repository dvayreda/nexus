# Pexels API Integration in n8n

Since Pexels node may not be available, use HTTP Request node:

## HTTP Request Node Setup
- **Method**: GET
- **URL**: https://api.pexels.com/v1/search
- **Headers**:
  - Authorization: {{ $credentials.pexelsApi.apiKey }}
- **Query Parameters**:
  - query: Your search term
  - per_page: 5 (or desired number)
- **Credential**: Create "Pexels API" with API Key field

## Response
Returns JSON with photos array. Extract image URLs for Canva integration.

## Alternative
Install community node if available: @n8n/n8n-nodes-pexels