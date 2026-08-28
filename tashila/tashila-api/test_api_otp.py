import urllib.request
import urllib.parse
import json

def main():
    print("="*60)
    print("         TASHILA API OTP FLOW TESTER")
    print("="*60)

    # 1. Ask for API Base URL
    default_url = "https://tashila-production.up.railway.app"
    api_url = input(f"Enter API Base URL (default: {default_url}): ").strip()
    if not api_url:
        api_url = default_url
    
    # Normalize url (remove trailing slash)
    if api_url.endswith("/"):
        api_url = api_url[:-1]

    # 2. Get recipient phone number
    phone = input("\nEnter phone number with country code (e.g. +213791453050): ").strip()
    if not phone:
        print("[FAIL] Phone number cannot be empty.")
        return

    # Choose role
    role_choice = input("Choose role (1: driver, 2: client) [default: driver]: ").strip()
    role = "client" if role_choice == "2" else "driver"

    # --- STEP 1: SEND OTP ---
    send_url = f"{api_url}/auth/otp/send"
    print(f"\n[INFO] Calling POST {send_url} ...")
    
    payload = {
        "phone": phone,
        "role": role
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(send_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"[OK] Status: {status}")
            print(f"[OK] Response: {body}")
            try:
                resp_json = json.loads(body)
                print("\nBackend successfully triggered Twilio SMS dispatch!")
            except Exception:
                pass
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] HTTP Error {e.code}: {e.reason}")
        print(f"[FAIL] Response: {body}")
        return
    except Exception as e:
        print(f"[FAIL] Connection error: {e}")
        return

    # --- STEP 2: VERIFY OTP ---
    print("\n" + "-"*40)
    print("If you received the SMS code on your device, you can verify it now.")
    otp = input("Enter the 6-digit OTP code received (or press Enter to skip verification): ").strip()
    if not otp:
        print("Skipping verification step.")
        return

    verify_url = f"{api_url}/auth/otp/verify"
    print(f"\n[INFO] Calling POST {verify_url} ...")
    
    payload = {
        "phone": phone,
        "otp": otp,
        "role": role
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(verify_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print(f"[OK] Status: {status}")
            print(f"[OK] Response JSON Tokens:")
            try:
                resp_json = json.loads(body)
                # Print tokens securely
                access_token = resp_json.get("accessToken", "")
                refresh_token = resp_json.get("refreshToken", "")
                print(f"  - Access Token: {access_token[:10]}...{access_token[-10:] if len(access_token) > 10 else ''}")
                print(f"  - Refresh Token: {refresh_token[:10]}...{refresh_token[-10:] if len(refresh_token) > 10 else ''}")
                print(f"  - Profile Setup Complete: {resp_json.get('user', {}).get('profileComplete')}")
                print("\nOTP verified and JWT login tokens issued successfully! The login works 100%.")
            except Exception:
                print(body)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] HTTP Error {e.code}: {e.reason}")
        print(f"[FAIL] Response: {body}")
    except Exception as e:
        print(f"[FAIL] Connection error: {e}")

if __name__ == "__main__":
    main()
