# outputs.tf
output "cloudfront_url" {
  description = "CloudFront Distribution URL (use this to access your website)"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_apigatewayv2_api.travelease_contact_api.api_endpoint}/${aws_apigatewayv2_stage.default.name}"
}

output "contact_form_endpoint" {
  description = "Full contact form endpoint URL"
  value       = "${aws_apigatewayv2_api.travelease_contact_api.api_endpoint}/${aws_apigatewayv2_stage.default.name}/contact"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.travelease_contact_submissions.name
}

output "lambda_function_names" {
  description = "Names of all Lambda functions"
  value = {
    submit_handler   = aws_lambda_function.submit_handler.function_name
    client_handler   = aws_lambda_function.client_handler.function_name
    business_handler = aws_lambda_function.business_handler.function_name
  }
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.travelease_contact_bucket_1700.bucket
}

output "ses_identities" {
  description = "SES Email Identities (verify these in your email)"
  value = {
    from_email    = var.from_email
    admin_email   = var.admin_email
    company_email = var.company_email
  }
}