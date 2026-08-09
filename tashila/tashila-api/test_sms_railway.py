import urllib.request
import urllib.error
import json

def test_sms():
    url = "https://www.traccar.org/sms/"
    token = "cKmWHO4vTZmpfDhUWtKAQq:APA91bHaYCBZ1A3zsTbhjZEXFk09nFJCb5pIUbGUsoHZlQN-1Ic29ahq7FBrkMuJCIyKQ-k0ielwkvQpkyQ5eGYSzeqlyWSs1v4FgJfg1AXN2-05ZLqw2DQ"
    
    # Standard format for Algerian numbers (country code +213)
    phone_number = "+213666408661"
    message = "Tashila SMS OTP Verification Test Code: 998877"

    print("="*60)
    print("SENDING TEST SMS VIA TRACCAR CLOUD RELAY")
    print("="*60)
    print(f"Target URL: {url}")
    print(f"To: {phone_number}")
    print(f"Message: {message}")
    print(f"Token: {token[:20]}...")

    headers = {
        "Content-Type": "application/json",
        "Authorization": token
    }
    
    data = json.dumps({
        "to": phone_number,
        "message": message
    }).encode("utf-8")
    
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8")
            print("\n[OK] Request Sent Successfully!")
            print(f"HTTP Status Code: {status}")
            print(f"Response Body: {body}")
            
            try:
                resp_json = json.loads(body)
                print(resp_json)
                if resp_json.get("successCount", 0) > 0:
                    print("\n[OK] successCount > 0! Traccar Cloud successfully queued the push notification to your phone.")
                    print("Please check your phone's Traccar SMS Gateway app to see if it received the push and dispatched the SMS.")
                else:
                    print("\n[FAIL] successCount is 0! The push notification was not queued. The Cloud Token may be invalid/expired or the phone is unregistered.")
            except Exception as json_err:
                print(f"Error parsing response: {json_err}")
                
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"\n[✗] HTTP Error {e.code}: {e.reason}")
        print(f"Response Body: {body}")
    except Exception as e:
        print(f"\n[✗] Network/Connection Error: {e}")
    print("="*60)

if __name__ == "__main__":
    test_sms()
