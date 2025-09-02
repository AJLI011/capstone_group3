# utils.py
import requests
import json
from django.conf import settings

def send_sms(recipient, message):
    """
    Send SMS using the PhilSMS API.

    Args:
        recipient (str): The phone number of the recipient.
        message (str): The message content.

    Returns:
        tuple: (success: bool, response: dict)
    """
    url = "https://app.philsms.com/api/v3/sms/send"
    headers = {
        "Authorization": f"Bearer {settings.PHILSMS_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "recipient": recipient,
        "sender_id": settings.PHILSMS_SENDER_ID,
        "type": "plain",
        "message": message,
    }

    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))

        # Try parsing JSON, fallback to raw text
        try:
            response_data = response.json()
        except ValueError:
            response_data = {"raw": response.text}

        # Handle API response
        if response.status_code == 200 and response_data.get("status") == "success":
            print("SMS sent successfully.")
            return True, response_data
        else:
            print(f"Error sending SMS. Status code: {response.status_code}, Response: {response_data}")
            return False, response_data

    except requests.exceptions.RequestException as e:
        print(f"Request error: {str(e)}")
        return False, {"error": str(e)}
