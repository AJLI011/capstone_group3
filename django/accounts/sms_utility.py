import requests
import json

def send_sms(recipient_number, message_content):
    """
    Sends a one-way SMS using the PhilSMS API.

    Args:
        recipient_number (str): The mobile number to send the SMS to (e.g., '639171234567').
        message_content (str): The body of the message.

    Returns:
        bool: True if the SMS was sent successfully, False otherwise.
        dict: The JSON response from the API.
    """
    # Replace with your actual PhilSMS API token
    # IMPORTANT: Do not hardcode this in a production environment. Use environment variables.
    api_token = "2452|OPoQSh85UxRd7Wo5vtRoBiHCHlWkwoKfiEnYNZ91"
    
    # You can change the sender_id to your desired name or number
    sender_id = "PhilSMS"
    
    url = "https://app.philsms.com/api/v3/sms/send"

    headers = {
        'Authorization': f'Bearer {"2452|OPoQSh85UxRd7Wo5vtRoBiHCHlWkwoKfiEnYNZ91"}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    payload = {
        'recipient': recipient_number,
        'sender_id': 'PhilSMS',
        'type': 'plain',
        'message': message_content
    }

    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        response.raise_for_status() # This will raise an HTTPError if the HTTP request returned an unsuccessful status code
        
        response_data = response.json()
        
        if response_data.get('status') == 'success':
            print("SMS sent successfully.")
            return True, response_data
        else:
            print(f"Error sending SMS: {response_data.get('message')}")
            return False, response_data
            
    except requests.exceptions.RequestException as e:
        print(f"An error occurred while sending the SMS: {e}")
        return False, {"status": "error", "message": str(e)}

if __name__ == '__main__':
    # This block is for testing the function directly
    # Replace with a real phone number and a test message
    test_number = '639567900840'
    test_message = 'This is a test notification from the Capstone project.'
    
    success, response = send_sms(test_number, test_message)
    print(f"Success: {success}")
    print(f"Response: {response}")