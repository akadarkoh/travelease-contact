import json
import boto3
import os

ses = boto3.client('ses', region_name='us-east-1')

def lambda_handler(event, context):
    """
    Sends notifications to admin and company
    """
    try:
        if 'Records' in event:
            for record in event['Records']:
                if record.get('eventName') == 'INSERT':
                    submission = record['dynamodb']['NewImage']
                    send_admin_notification(submission)
                    send_company_notification(submission)
        
        return {'statusCode': 200, 'body': json.dumps({'message': 'Business emails processed'})}
        
    except Exception as e:
        print(f"Error processing business emails: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def send_admin_notification(submission):
    """Send notification to admin"""
    # Convert DynamoDB format if needed
    if isinstance(submission, dict) and 'S' in next(iter(submission.values()), {}):
        submission = {k: v.get('S', '') for k, v in submission.items()}
    
    admin_subject = f"New Travel Inquiry - {submission.get('name')}"
    
    admin_body = f"""
🆕 NEW TRAVEL INQUIRY

Client Details:
👤 Name: {submission.get('name')}
📧 Email: {submission.get('email')}
📞 Phone: {submission.get('phone', 'Not provided')}
🏢 Company: {submission.get('company', 'Not provided')}

Subject: {submission.get('subject', 'Not provided')}

Travel Dates: {submission.get('travelease_dates', 'Not provided')}
Budget: {submission.get('budget', 'Not provided')}

Message:
{submission.get('message')}

Reference ID: {submission.get('submission_id')}
Received: {submission.get('timestamp')}

Please respond within 24 hours.
    """
    
    try:
        ses.send_email(
            Source=os.environ['FROM_EMAIL'],
            Destination={'ToAddresses': [os.environ['ADMIN_EMAIL']]},
            Message={
                'Subject': {'Data': admin_subject},
                'Body': {'Text': {'Data': admin_body}}
            }
        )
        print(f"Admin notification sent to {os.environ['ADMIN_EMAIL']}")
    except Exception as e:
        print(f"Failed to send admin email: {str(e)}")

def send_company_notification(submission):
    """Send internal notification to company"""
    # Convert DynamoDB format if needed
    if isinstance(submission, dict) and 'S' in next(iter(submission.values()), {}):
        submission = {k: v.get('S', '') for k, v in submission.items()}
    
    company_subject = f"New Lead - {submission.get('name')}"
    
    company_body = f"""
🎯 NEW LEAD CAPTURED

Lead Details:
Name: {submission.get('name')}
Email: {submission.get('email')} 
Company: {submission.get('company', 'Direct')}
Phone: {submission.get('phone', 'Not provided')}
Source: Travel Contact Form

Travel Details:
Dates: {submission.get('travelease_dates', 'Not specified')}
Budget: {submission.get('budget', 'Not specified')}

Message:
{submission.get('message')}

Lead ID: {submission.get('submission_id')}
Timestamp: {submission.get('timestamp')}

This lead has been captured in the system.
    """
    
    try:
        ses.send_email(
            Source=os.environ['FROM_EMAIL'],
            Destination={'ToAddresses': [os.environ['COMPANY_EMAIL']]},
            Message={
                'Subject': {'Data': company_subject},
                'Body': {'Text': {'Data': company_body}}
            }
        )
        print(f"Company notification sent to {os.environ['COMPANY_EMAIL']}")
    except Exception as e:
        print(f"Failed to send company email: {str(e)}")