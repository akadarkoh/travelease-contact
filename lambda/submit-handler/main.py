import json
import os
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])  # ✅ Fixed: Use environment variable

def lambda_handler(event, context):
    # CORS headers for browser requests
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    }

    # Handle CORS preflight requests
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'CORS Preflight'})
        }
    
    try:
        # Parse the request body
        body = json.loads(event.get('body', '{}'))

        # Validate required fields based on form
        required_fields = ['name', 'email', 'message']
        for field in required_fields:
            if field not in body or not body[field].strip():
                return {
                    'statusCode': 400,
                    'headers': cors_headers,
                    'body': json.dumps({'error': f'Missing required field: {field}'})
                } 

        # Create submission record
        submission_id = str(uuid.uuid4())
        item = {
            'submission_id': submission_id,
            'name': body['name'],
            'email': body['email'],
            'message': body['message'],
            'timestamp': datetime.now().isoformat(),
            'status': 'new',
            'type': 'business_contact'
        }

        # Add optional fields
        for field in ['phone', 'company', 'subject', 'travelease_dates', 'budget']:
            if field in body and body[field]:
                item[field] = body[field]

        # Save to DynamoDB
        table.put_item(Item=item)

        # Return success
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'message': 'Travel form submitted successfully',
                'submission_id': submission_id
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")  # Log to CloudWatch
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }