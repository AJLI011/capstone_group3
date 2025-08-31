# firebase.py

import os
import firebase_admin
from firebase_admin import credentials, messaging, exceptions as firebase_exceptions

# Get the absolute path of the JSON file inside the backend folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FIREBASE_JSON_PATH = os.path.join(BASE_DIR, 'capstone-dedd4-firebase-adminsdk-fbsvc-69e67e0cac.json')

# Initialize Firebase app
try:
    cred = credentials.Certificate(FIREBASE_JSON_PATH)
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized successfully!")
except Exception as e:
    print(f"Error initializing Firebase Admin SDK: {e}")

# Helper function to send FCM notifications
def send_fcm_notification(token: str, title: str, body: str):
    """
    Send a push notification to a specific device using the Firebase Admin SDK.
    Args:
        token (str): The FCM device token
        title (str): Notification title
        body (str): Notification body
    """
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        # Send the message
        response = messaging.send(message)
        print(f"✅ FCM notification sent successfully: {response}")
    # FIX: Catch the specific error for better logging
    except firebase_exceptions.NotFoundError as e:
        print(f"⚠️ Failed to send FCM notification: Requested entity was not found.")
        print(f"Error details: {e}")
    except firebase_exceptions.FirebaseError as e:
        # Catch other generic Firebase errors
        print(f"⚠️ An unknown Firebase error occurred: {e}")
    except Exception as e:
        # Catch all other exceptions
        print(f"⚠️ An unexpected error occurred: {e}")