import json
import re

def extract_json_from_text(text: str) -> dict | None:
    try:
        match = re.search(r"```json\n(.*?)\n```", text, re.DOTALL)
        if match:
            return json.loads(match.group(1))

        fallback_match = re.search(r"(\{.*\})", text, re.DOTALL)
        if fallback_match:
            return json.loads(fallback_match.group(1))

    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
    return None
