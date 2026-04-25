import urllib.request
import json
import os

try:
    req = urllib.request.Request("https://openrouter.ai/api/v1/auth/key", method="GET")
    req.add_header("Authorization", "Bearer INVALID_KEY")
    with urllib.request.urlopen(req) as response:
        print(response.read())
except Exception as e:
    print(f"OpenRouter Auth: {e}")
