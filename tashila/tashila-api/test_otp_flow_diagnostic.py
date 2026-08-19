import urllib.request
import urllib.parse
import json
import ssl

def main():
    print("="*65)
    print("        TASHILA API OTP FLOW DIAGNOSTIC TOOL")
    print("="*65)

    # 1. Base URL
    default_url = "https://tashila-production.up.railway.app"
    api_url = input(f"Enter API Base URL (default: {default_url}): ").strip()
    if not api_url:
        api_url = default_url
    if api_url.endswith("/"):
        api_url = api_url[:-1]

    # 2. Recipient Phone
    phone = input("\nEnter phone number with country code (e.g. +213666408661): ").strip()
    if not phone:
        print("[FAIL] Phone number cannot be empty.")
        return

    # Choose role
    role_choice = input("Choose role (1: driver, 2: client) [default: driver]: ").strip()
    role = "client" if role_choice == "2" else "driver"

    # --- STEP 1: SEND OTP ---
    send_url = f"{api_url}/auth/otp/send"
    print(f"\n[STEP 1] Calling POST {send_url} ...")
    
    payload = {
        "phone": phone,
        "role": role
    }
    
    print(f"[REQ PAYLOAD] {json.dumps(payload)}")
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(send_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    # Disable SSL verification checks if needed, to avoid cert errors in some environments
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, context=ctx, timeout=20) as response:
            status = response.status
            headers = dict(response.info())
            body = response.read().decode("utf-8")
            print(f"[RESP STATUS] {status}")
            print(f"[RESP HEADERS] {json.dumps(headers, indent=2)}")
            print(f"[RESP BODY] {body}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] STEP 1 HTTP Error {e.code}: {e.reason}")
        print(f"[RESP HEADERS] {json.dumps(dict(e.info()), indent=2)}")
        print(f"[RESP BODY] {body}")
        return
    except Exception as e:
        print(f"[FAIL] STEP 1 Connection error: {e}")
        return

    # --- STEP 2: VERIFY OTP ---
    print("\n" + "-"*50)
    otp = input("Enter the OTP code received on your device (or '1111' if using test OTP): ").strip()
    if not otp:
        print("Skipping verification step.")
        return

    verify_url = f"{api_url}/auth/otp/verify"
    print(f"\n[STEP 2] Calling POST {verify_url} ...")
    
    payload = {
        "phone": phone,
        "otp": otp,
        "role": role
    }
    
    print(f"[REQ PAYLOAD] {json.dumps(payload)}")
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(verify_url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, context=ctx, timeout=20) as response:
            status = response.status
            headers = dict(response.info())
            body = response.read().decode("utf-8")
            print(f"[RESP STATUS] {status}")
            print(f"[RESP HEADERS] {json.dumps(headers, indent=2)}")
            print(f"[RESP BODY] {body}")
            
            try:
                resp_json = json.loads(body)
                access_token = resp_json.get("accessToken", "")
                if access_token:
                    print("\n[SUCCESS] OTP verified successfully and JWT tokens issued!")
                else:
                    print("\n[WARNING] Response received but accessToken is missing.")
            except Exception:
                pass
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"[FAIL] STEP 2 HTTP Error {e.code}: {e.reason}")
        print(f"[RESP HEADERS] {json.dumps(dict(e.info()), indent=2)}")
        print(f"[RESP BODY] {body}")
    except Exception as e:
        print(f"[FAIL] STEP 2 Connection error: {e}")

if __name__ == "__main__":
    main()
