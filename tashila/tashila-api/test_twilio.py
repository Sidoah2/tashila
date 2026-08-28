import os
import re
import urllib.request
import urllib.parse
import base64
import json

def load_env(env_path):
    config = {}
    if not os.path.exists(env_path):
        return config
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                config[key.strip()] = val.strip()
    return config

def main():
    print("="*60)
    print("           TWILIO SMS DIAGNOSTIC TEST")
    print("="*60)

    # 1. Load .env
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    env = load_env(env_path)

    account_sid = env.get("TWILIO_ACCOUNT_SID", "")
    auth_token = env.get("TWILIO_AUTH_TOKEN", "")
    phone_number = env.get("TWILIO_PHONE_NUMBER", "")

    print(f"[INFO] Loaded TWILIO_ACCOUNT_SID: {account_sid}")
    print(f"[INFO] Loaded TWILIO_AUTH_TOKEN: {auth_token[:4]}***{auth_token[-4:] if len(auth_token) > 4 else ''}")
    print(f"[INFO] Loaded TWILIO_PHONE_NUMBER: {phone_number}")

    if not account_sid or not auth_token or not phone_number:
        print("[FAIL] Missing Twilio credentials in .env. Please check the file.")
        return

    # 2. Get recipient phone
    recipient = input("\nEnter recipient phone number (with country code, e.g. +213791453050): ").strip()
    if not recipient:
        print("[FAIL] Recipient number cannot be empty.")
        return

    # 3. Form request
    url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
    
    data = {
        "To": recipient,
        "From": phone_number,
        "Body": "Tashila Twilio Test OTP: 999999"
    }
    
    encoded_data = urllib.parse.urlencode(data).encode("utf-8")
    
    # HTTP Basic Authentication
    auth_str = f"{account_sid}:{auth_token}"
    auth_bytes = auth_str.encode("utf-8")
    auth_b64 = base64.b64encode(auth_bytes).decode("utf-8")
    
    req = urllib.request.Request(url, data=encoded_data, method="POST")
    req.add_header("Authorization", f"Basic {auth_b64}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    print("\nSending test SMS to Twilio...")
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"\n[OK] Twilio returned HTTP Status {status}")
            try:
                resp_json = json.loads(body)
                print(f"[OK] Message SID: {resp_json.get('sid')}")
                print(f"[OK] Status: {resp_json.get('status')}")
                print("\nSuccess! Check the phone for the SMS message.")
            except Exception:
                print(f"[INFO] Response Body: {body}")
    except urllib.error.HTTPError as e:
        status = e.code
        body = e.read().decode("utf-8")
        print(f"\n[FAIL] Twilio API HTTP Error {status}: {e.reason}")
        try:
            resp_json = json.loads(body)
            print(f"[FAIL] Error Code: {resp_json.get('code')}")
            print(f"[FAIL] Error Message: {resp_json.get('message')}")
            print(f"[FAIL] More Info: {resp_json.get('more_info')}")
        except Exception:
            print(f"[FAIL] Response Body: {body}")
    except Exception as e:
        print(f"\n[FAIL] Connection error: {e}")

if __name__ == "__main__":
    main()
