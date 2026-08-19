import os
import re
import urllib.request
import urllib.parse
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

def clean_phone_for_smssak(phone: str) -> tuple[str, str]:
    cleaned = re.sub(r"[^\d+]", "", phone or "")
    if cleaned.startswith("+213"):
        local = "0" + cleaned[4:]
        return "dz", local
    elif cleaned.startswith("213"):
        local = "0" + cleaned[3:]
        return "dz", local
    elif cleaned.startswith("0") and len(cleaned) == 10:
        return "dz", cleaned
    elif len(cleaned) == 9 and cleaned[0] in ("5", "6", "7"):
        return "dz", "0" + cleaned
    else:
        stripped = cleaned.lstrip("+")
        return "dz", stripped

def main():
    print("="*60)
    print("           SMSSAK SMS DIAGNOSTIC TEST")
    print("="*60)

    # Load .env
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    env = load_env(env_path)

    api_key = env.get("SMSSAK_API_KEY", "")
    project_id = env.get("SMSSAK_PROJECT_ID", "")
    country_default = env.get("SMSSAK_COUNTRY", "dz")

    print(f"[INFO] Loaded SMSSAK_API_KEY: {api_key[:10]}***")
    print(f"[INFO] Loaded SMSSAK_PROJECT_ID: {project_id}")
    print(f"[INFO] Loaded SMSSAK_COUNTRY: {country_default}")

    if not api_key or not project_id:
        print("[FAIL] Missing SMSSAK credentials in .env. Please check the file.")
        return

    # Get recipient phone
    recipient = input("\nEnter recipient phone number (e.g. +213791453050): ").strip()
    if not recipient:
        print("[FAIL] Recipient number cannot be empty.")
        return

    country_code, local_phone = clean_phone_for_smssak(recipient)
    print(f"[INFO] Normalized number for SMSSAK - Country: {country_code.upper()}, Local Phone: {local_phone}")

    # Let's test both sendmessage and sendotp
    print("\n--- TEST 1: sendmessage endpoint ---")
    url_msg = "https://sendmessage-47lvvvrp4a-uc.a.run.app"
    headers = {
        "Content-Type": "application/json",
        "key": api_key
    }
    payload_msg = {
        "country": country_code.upper(),
        "phone": local_phone,
        "projectId": project_id,
        "message": "Tashila SMSSAK Diagnostic Test OTP: 888888"
    }
    data_msg = json.dumps(payload_msg).encode("utf-8")
    req_msg = urllib.request.Request(url_msg, data=data_msg, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req_msg, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"[OK] sendmessage returned HTTP Status {status}")
            print(f"[OK] Response: {body}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] sendmessage HTTP Error {e.code}: {e.reason}")
        print(f"[FAIL] Response: {body}")
    except Exception as e:
        print(f"[FAIL] sendmessage connection error: {e}")

    print("\n--- TEST 2: sendotp endpoint ---")
    url_otp = "https://sendotp-47lvvvrp4a-uc.a.run.app"
    payload_otp = {
        "country": country_code.upper(),
        "phone": local_phone,
        "projectId": project_id,
        "type": "sms"
    }
    data_otp = json.dumps(payload_otp).encode("utf-8")
    req_otp = urllib.request.Request(url_otp, data=data_otp, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req_otp, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"[OK] sendotp returned HTTP Status {status}")
            print(f"[OK] Response: {body}")
            print("\nIf successful, you will receive a 4-digit code from SMSSAK.")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] sendotp HTTP Error {e.code}: {e.reason}")
        print(f"[FAIL] Response: {body}")
    except Exception as e:
        print(f"[FAIL] sendotp connection error: {e}")

    print("\n--- TEST 3: verifyotp endpoint ---")
    otp_code = input("Enter the OTP code received on your device (or press Enter to skip verify test): ").strip()
    if otp_code:
        url_verify = "https://verifyotp-47lvvvrp4a-uc.a.run.app"
        payload_verify = {
            "country": country_code.upper(),
            "phone": local_phone,
            "projectId": project_id,
            "otp": otp_code
        }
        data_verify = json.dumps(payload_verify).encode("utf-8")
        req_verify = urllib.request.Request(url_verify, data=data_verify, headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req_verify, timeout=15) as response:
                status = response.status
                body = response.read().decode("utf-8")
                print(f"[OK] verifyotp returned HTTP Status {status}")
                print(f"[OK] Response: {body}")
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8")
            print(f"[FAIL] verifyotp HTTP Error {e.code}: {e.reason}")
            print(f"[FAIL] Response Headers: {json.dumps(dict(e.info()), indent=2)}")
            print(f"[FAIL] Response Body: {body}")
        except Exception as e:
            print(f"[FAIL] verifyotp connection error: {e}")

if __name__ == "__main__":
    main()
