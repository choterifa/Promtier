import urllib.request
import json

req = urllib.request.Request("https://openrouter.ai/api/v1/models", method="GET")
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read())
    free_models = [m['id'] for m in data.get('data', []) if m.get('pricing', {}).get('prompt') == '0' and m.get('pricing', {}).get('completion') == '0']
    print(f"Total: {len(data['data'])}")
    print(f"Free: {len(free_models)}")
    print(free_models[:5])
