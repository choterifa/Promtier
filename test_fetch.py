import urllib.request
import json

try:
    req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/models?key=INVALID", method="GET")
    with urllib.request.urlopen(req) as response:
        print(response.read())
except Exception as e:
    print(f"Gemini: {e}")

try:
    req = urllib.request.Request("https://openrouter.ai/api/v1/models", method="GET")
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read())
        print(f"OpenRouter: {len(data.get('data', []))} models found")
        if len(data.get('data', [])) > 0:
            print("First OpenRouter model:", data['data'][0]['id'])
except Exception as e:
    print(f"OpenRouter: {e}")
