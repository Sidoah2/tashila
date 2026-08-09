import os
import sys
import json
import socket
import urllib.request
import urllib.error

# Helper for printing in colors
def print_success(msg):
    print(f"[OK] {msg}")

def print_failure(msg):
    print(f"[FAIL] {msg}")

def print_info(msg):
    print(f"[INFO] {msg}")

def print_warning(msg):
    print(f"[WARN] {msg}")


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

def check_tcp_port(ip, port, timeout=5):
    print_info(f"Checking if port {port} on {ip} is reachable...")
    try:
        with socket.create_connection((ip, port), timeout=timeout):
            print_success(f"Successfully connected to {ip}:{port} over the network.")
            return True
    except Exception as e:
        print_failure(f"Failed to connect to {ip}:{port}. Error: {e}")
        return False

def test_local_gateway(url, api_key, phone, message):
    print("\n" + "="*50)
    print_info(f"Testing LOCAL GATEWAY Direct Request...")
    print_info(f"Target URL: {url}")
    print_info(f"Phone: {phone}")
    print_info(f"Message: {message}")
    
    headers = {
        "Content-Type": "application/json"
    }
    if api_key:
        headers["Authorization"] = api_key
        print_info(f"Using Authorization Key: {api_key[:10]}...")
    else:
        print_info("No Authorization Key provided.")

    data = json.dumps({"to": phone, "message": message}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print_success(f"Local gateway returned HTTP Status {status}")
            print_info(f"Response Body: {body}")
            try:
                resp_json = json.loads(body)
                if resp_json.get("successCount", 0) > 0 or resp_json.get("success", False):
                    print_success("Gateway accepted the request! Check the phone for SMS dispatch.")
                else:
                    print_warning("Gateway responded but success count is 0 or success is false. Check phone logs/SIM status.")
            except Exception:
                print_info("Response is not JSON, but request succeeded. Check phone.")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print_failure(f"Local gateway HTTP Error {e.code}: {e.reason}")
        print_info(f"Response Body: {body}")
    except Exception as e:
        print_failure(f"Local gateway connection error: {e}")

def test_cloud_relay(token, phone, message):
    print("\n" + "="*50)
    print_info("Testing CLOUD RELAY (traccar.org/sms)...")
    url = "https://www.traccar.org/sms/"
    print_info(f"Target URL: {url}")
    print_info(f"Token: {token[:15]}...")
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": token
    }
    
    data = json.dumps({"to": phone, "message": message}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print_success(f"Cloud Relay returned HTTP Status {status}")
            print_info(f"Response Body: {body}")
            try:
                resp_json = json.loads(body)
                if resp_json.get("successCount", 0) > 0:
                    print_success("Cloud Relay successfully pushed to Google FCM. The message is queued.")
                    print_warning("Note: This only means the cloud server sent the push notification. If your phone is offline, has FCM disabled, or battery optimizer is active, the phone won't receive it or send the SMS.")
                else:
                    print_failure("Cloud Relay reported 0 successCount. The token might be invalid/expired or phone disconnected.")
            except Exception:
                print_info("Response format unknown.")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print_failure(f"Cloud Relay HTTP Error {e.code}: {e.reason}")
        print_info(f"Response Body: {body}")
    except Exception as e:
        print_failure(f"Cloud Relay connection error: {e}")

def main():
    print("="*60)
    print("       TRACCAR SMS GATEWAY DIAGNOSTIC TOOL")
    print("="*60)

    # 1. Load env configuration
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    env = load_env(env_path)
    
    token = env.get("TRACCAR_SMS_TOKEN", "")
    if not token:
        print_warning("No TRACCAR_SMS_TOKEN found in .env.")
    else:
        print_success(f"Loaded TRACCAR_SMS_TOKEN from .env: {token[:15]}...")

    # 2. Get test parameters
    phone = input("\nEnter recipient phone number (with country code, e.g. +213791453050): ").strip()
    if not phone:
        phone = "+213791453050"
        print_info(f"Using default phone number: {phone}")

    message = "Tashila SMS Test OTP: 123456"

    # 3. Test Local Gateway Option
    print("\n--- LOCAL GATEWAY CONFIGURATION ---")
    print_info("Use this if your phone is running a local HTTP server (e.g., over Tailscale).")
    local_ip = input("Enter phone IP address (default: 100.137.138.208): ").strip()
    if not local_ip:
        local_ip = "100.137.138.208"
    
    local_port = input("Enter port (default: 8082): ").strip()
    if not local_port:
        local_port = "8082"
    
    local_url = f"http://{local_ip}:{local_port}"
    
    local_api_key = input("Enter API Key/Authorization for local app (if any, default: none): ").strip()

    # Reachability test
    is_reachable = False
    try:
        port_num = int(local_port)
        is_reachable = check_tcp_port(local_ip, port_num)
    except ValueError:
        print_failure("Invalid port number.")

    # Send test locally
    test_local_gateway(local_url, local_api_key, phone, message)

    # 4. Test Cloud Relay Option (using the env token)
    if token:
        test_cloud_relay(token, phone, message)
    else:
        print("\nSkipping Cloud Relay test because no TRACCAR_SMS_TOKEN was found.")
        token_input = input("Enter Cloud Token manually to test Cloud Relay (or press Enter to skip): ").strip()
        if token_input:
            test_cloud_relay(token_input, phone, message)

    print("\n" + "="*50)
    print("DIAGNOSTIC SUMMARY & TROUBLESHOOTING:")
    print("1. If Local Gateway failed to connect:")
    print("   - Make sure your phone has Tailscale turned ON and connected.")
    print("   - Make sure your PC is on the same Tailscale network.")
    print("   - Check if you can ping the phone IP from this PC.")
    print("   - In the Traccar SMS Gateway app, make sure 'HTTP Server' is switched ON.")
    print("2. If Cloud Relay returned success but no SMS was received:")
    print("   - Make sure your phone's Traccar SMS Gateway app is running in the background.")
    print("   - Disable battery optimization/battery saver for the Traccar SMS Gateway app.")
    print("   - Check the FCM token in your .env: if you reinstalled the app, the Cloud Token changed.")
    print("   - Ensure Google Play Services are enabled and connected.")
    print("3. Check App Permissions:")
    print("   - Verify that 'Send and view SMS messages' and 'Read phone status' permissions are granted.")
    print("="*60)

if __name__ == "__main__":
    main()
