resource "aws_iam_role" "apigw_cloudwatch" {
  name = "role-apigateway-cloudwatch-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.apigw_cloudwatch]
}

resource "aws_cloudwatch_log_group" "apigw_stage" {
  name              = "/aws/apigateway/${var.api_name}/${var.environment}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = var.apigateway_id

  triggers = {
    redeployment = sha1(file("${path.module}/openapi-resolved.json"))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = var.apigateway_id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment

  depends_on = [aws_api_gateway_account.this]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_stage.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.common_tags
}