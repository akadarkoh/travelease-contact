resource "aws_s3_bucket" "travelease_contact_bucket_1700" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.form_completion
  }
}

resource "aws_s3_bucket_website_configuration" "travelease_contact_website_1700" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 Objects for website files
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  key    = "index.html"
  source = "../frontend/index.html"
  content_type = "text/html"
  etag = filemd5("../frontend/index.html")
}

resource "aws_s3_object" "styles" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  key    = "styles.css"
  source = "../frontend/styles.css"
  content_type = "text/css"
  etag = filemd5("../frontend/styles.css")
}

resource "aws_s3_object" "script" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  key    = "script.js"
  source = "../frontend/script.js"
  content_type = "application/javascript"
  etag = filemd5("../frontend/script.js")
}

resource "aws_s3_object" "error" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  key    = "error.html"
  source = "../frontend/error.html"
  content_type = "text/html"
  etag = filemd5("../frontend/error.html")
}

resource "aws_s3_object" "app_config" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  key = "config.js"
  content = templatefile("${path.module}/../frontend/config.js.tpl", {
    api_url = "${aws_apigatewayv2_api.travelease_contact_api.api_endpoint}/${aws_apigatewayv2_stage.default.name}/contact"
  })
  content_type = "application/javascript"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.travelease_contact_bucket_1700.bucket_regional_domain_name
    origin_id   = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.travelease_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "travelease-contact-distribution"
  }
}

resource "aws_cloudfront_origin_access_control" "travelease_oac" {
  name                              = "travelease-oac"
  description                       = "OAC for Travelease S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "cloudfront_only" {
  bucket = aws_s3_bucket.travelease_contact_bucket_1700.id
  policy = data.aws_iam_policy_document.cloudfront_only.json
}

data "aws_iam_policy_document" "cloudfront_only" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.travelease_contact_bucket_1700.arn}/*"]
    
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "travelease_contact_api" {
  name          = "travelease-contact-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }
}

# Lambda Functions
resource "aws_lambda_function" "submit_handler" {
  filename      = "../lambda/submit-handler.zip"
  function_name = "travelease-submit-handler"
  role          = aws_iam_role.travelease_contact_lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"  # ✅ Fixed: Updated from 3.8
  timeout       = 30
  
  source_code_hash = filebase64sha256("../lambda/submit-handler.zip")
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.travelease_contact_submissions.name
      FROM_EMAIL     = var.from_email
      ADMIN_EMAIL    = var.admin_email
      COMPANY_EMAIL  = var.company_email
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.travelease_contact_lambda_role_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_dynamodb_attachment,
  ]
}

resource "aws_lambda_function" "client_handler" {
  filename      = "../lambda/client-handler.zip"
  function_name = "travelease-client-handler"
  role          = aws_iam_role.travelease_contact_lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"  # ✅ Fixed: Updated from 3.8
  timeout       = 30
  
  source_code_hash = filebase64sha256("../lambda/client-handler.zip")
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.travelease_contact_submissions.name
      FROM_EMAIL     = var.from_email
      ADMIN_EMAIL    = var.admin_email
      COMPANY_EMAIL  = var.company_email
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.travelease_contact_lambda_role_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_dynamodb_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_ses_attachment,
  ]
}

resource "aws_lambda_function" "business_handler" {
  filename      = "../lambda/business-handler.zip"
  function_name = "travelease-business-handler"
  role          = aws_iam_role.travelease_contact_lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"  # ✅ Fixed: Updated from 3.8
  timeout       = 30
  
  source_code_hash = filebase64sha256("../lambda/business-handler.zip")
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.travelease_contact_submissions.name
      FROM_EMAIL     = var.from_email
      ADMIN_EMAIL    = var.admin_email
      COMPANY_EMAIL  = var.company_email
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.travelease_contact_lambda_role_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_dynamodb_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_ses_attachment,
    aws_iam_role_policy_attachment.travelease_contact_lambda_sns_attachment
  ]
}

# IAM Role and Policies
resource "aws_iam_role" "travelease_contact_lambda_role" {
  name = "travelease-contact-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "travelease_contact_lambda_role_attachment" {
  role       = aws_iam_role.travelease_contact_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "travelease_contact_lambda_integration" {
  api_id           = aws_apigatewayv2_api.travelease_contact_api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  integration_uri  = aws_lambda_function.submit_handler.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "travelease_contact_route" {
  api_id    = aws_apigatewayv2_api.travelease_contact_api.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.travelease_contact_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "travelease_contact_route_options" {
  api_id    = aws_apigatewayv2_api.travelease_contact_api.id
  route_key = "OPTIONS /contact"
  target    = "integrations/${aws_apigatewayv2_integration.travelease_contact_lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.travelease_contact_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "travelease_contact_permissions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.travelease_contact_api.execution_arn}/*/*/contact"
}

# DynamoDB
resource "aws_dynamodb_table" "travelease_contact_submissions" {
  name         = "travelease-contact-submissions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "submission_id"

  stream_enabled = true
  stream_view_type = "NEW_IMAGE"
  
  attribute {
    name = "submission_id"
    type = "S"
  }
  
  tags = {
    Name        = "travelease-contact-submissions"
    Environment = var.processing
  }
}

# Event source mapping for handlers
resource "aws_lambda_event_source_mapping" "client_email_trigger" {
  event_source_arn = aws_dynamodb_table.travelease_contact_submissions.stream_arn
  function_name = aws_lambda_function.client_handler.arn
  starting_position = "LATEST"

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
      })
    }
  }
}

resource "aws_lambda_event_source_mapping" "business_email_trigger" {
  event_source_arn = aws_dynamodb_table.travelease_contact_submissions.stream_arn
  function_name = aws_lambda_function.business_handler.arn
  starting_position = "LATEST"

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
      })
    }
  }
}

# DynamoDB IAM Policy
resource "aws_iam_policy" "travelease_contact_dynamodb_access" {
  name        = "travelease-dynamodb-access"
  description = "Policy for lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams",
          "dynamodb:Query",
          "dynamodb:Scan", 
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem"
        ],
        Resource = [
          aws_dynamodb_table.travelease_contact_submissions.arn,
          "${aws_dynamodb_table.travelease_contact_submissions.arn}/stream/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "travelease_contact_lambda_dynamodb_attachment" {
  role       = aws_iam_role.travelease_contact_lambda_role.name
  policy_arn = aws_iam_policy.travelease_contact_dynamodb_access.arn
}

# SES
resource "aws_ses_email_identity" "sender_email" {
  email = var.from_email
}

resource "aws_ses_email_identity" "admin_email" {
  email = var.admin_email
}

resource "aws_ses_email_identity" "company_email" {
  email = var.company_email
}

# SES IAM Policy
resource "aws_iam_policy" "travelease_contact_ses_access" {
  name        = "travelease-ses-access"
  description = "Policy for lambda to access SES"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "travelease_contact_lambda_ses_attachment" {
  role       = aws_iam_role.travelease_contact_lambda_role.name
  policy_arn = aws_iam_policy.travelease_contact_ses_access.arn
}

# SNS
resource "aws_sns_topic" "travelease_contact_submissions" {
  name = "travelease-contact-submissions"
}

resource "aws_sns_topic_policy" "cloudwatch_alarm_policy" {
  arn = aws_sns_topic.travelease_contact_submissions.arn
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action = "sns:Publish",
        Resource = aws_sns_topic.travelease_contact_submissions.arn
      }
    ]
  })
}

# SNS IAM Policy
resource "aws_iam_policy" "travelease_contact_sns_access" {
  name        = "travelease-sns-access"
  description = "Policy for lambda to access SNS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = aws_sns_topic.travelease_contact_submissions.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "travelease_contact_lambda_sns_attachment" {
  role       = aws_iam_role.travelease_contact_lambda_role.name
  policy_arn = aws_iam_policy.travelease_contact_sns_access.arn
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "travelease-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors lambda function errors"
  alarm_actions       = [aws_sns_topic.travelease_contact_submissions.arn]
  
  dimensions = {
    FunctionName = aws_lambda_function.submit_handler.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "travelease-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.travelease_contact_submissions.arn]
  
  dimensions = {
    ApiId = aws_apigatewayv2_api.travelease_contact_api.id
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled_requests" {
  alarm_name          = "travelease-dynamodb-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors DynamoDB throttled requests"
  alarm_actions       = [aws_sns_topic.travelease_contact_submissions.arn]
  
  dimensions = {
    TableName = aws_dynamodb_table.travelease_contact_submissions.name
  }
}