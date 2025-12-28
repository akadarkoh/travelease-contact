import json
import boto3
import os

ses = boto3.client('ses', region_name='us-east-1')

def lambda_handler(event, context):
    """
    Sends confirmation emails to users/clients
    Triggered when new form submissions occur
    """
    try:
        # Extract submission data from DynamoDB stream event
        if 'Records' in event:
            for record in event['Records']:
                if record.get('eventName') == 'INSERT':
                    submission = record['dynamodb']['NewImage']
                    send_client_confirmation(submission)
        
        return {'statusCode': 200, 'body': json.dumps({'message': 'Client emails processed'})}
        
    except Exception as e:
        print(f"Error processing client emails: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def send_client_confirmation(submission):
    """Send confirmation email to the user/client"""
    # Convert DynamoDB format to regular dict
    if isinstance(submission, dict) and 'S' in next(iter(submission.values()), {}):
        submission = {k: v.get('S', '') for k, v in submission.items()}
    
    client_subject = "Thank You for Contacting TravelEase!"
    
    client_body = f"""
Dear {submission.get('name', 'Valued Customer')},

Thank you for your interest in TravelEase! We have received your inquiry and our team will contact you shortly.

Inquiry Summary:
- Reference ID: {submission.get('submission_id', 'N/A')}
- Submitted: {submission.get('timestamp', 'N/A')}

Your Message:
{submission.get('message', 'N/A')}

We look forward to assisting you with your travel needs!

Best regards,
The TravelEase Team
📞 Contact: support@travelease.com
🌐 Website: www.travelease.com
    """
    
    try:
        ses.send_email(
            Source=os.environ['COMPANY_EMAIL'],
            Destination={'ToAddresses': [submission.get('email')]},
            Message={
                'Subject': {'Data': client_subject},
                'Body': {'Text': {'Data': client_body}}
            }
        )
        print(f"Confirmation email sent to {submission.get('email')}")
    except Exception as e:
        print(f"Failed to send email to {submission.get('email')}: {str(e)}")
        # Don't raise exception - we don't want to fail the entire process