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

# ── MailPit passthrough ──────────────────────────────────────
# Plumbing-only route for the dev inbox, not part of the OpenAPI contract, so it's
# provisioned directly in Terraform instead of the OpenAPI spec and never shows up
# in the published Swagger docs.

data "aws_api_gateway_resource" "root" {
  rest_api_id = var.apigateway_id
  path        = "/"
}

resource "aws_api_gateway_resource" "mailpit" {
  rest_api_id = var.apigateway_id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "mailpit"
}

resource "aws_api_gateway_resource" "mailpit_proxy" {
  rest_api_id = var.apigateway_id
  parent_id   = aws_api_gateway_resource.mailpit.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "mailpit_root" {
  rest_api_id   = var.apigateway_id
  resource_id   = aws_api_gateway_resource.mailpit.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mailpit_root" {
  rest_api_id             = var.apigateway_id
  resource_id             = aws_api_gateway_resource.mailpit.id
  http_method             = aws_api_gateway_method.mailpit_root.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.mailpit_base_url}/${var.environment}/mailpit/"
  connection_type         = "INTERNET"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method" "mailpit_proxy" {
  rest_api_id   = var.apigateway_id
  resource_id   = aws_api_gateway_resource.mailpit_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "mailpit_proxy" {
  rest_api_id             = var.apigateway_id
  resource_id             = aws_api_gateway_resource.mailpit_proxy.id
  http_method             = aws_api_gateway_method.mailpit_proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.mailpit_base_url}/${var.environment}/mailpit/{proxy}"
  connection_type         = "INTERNET"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = var.apigateway_id

  triggers = {
    redeployment = sha1(join(",", [
      file("${path.module}/openapi-resolved.json"),
      "mailpit:${var.mailpit_base_url}",
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_account.this,
    aws_api_gateway_integration.mailpit_root,
    aws_api_gateway_integration.mailpit_proxy,
  ]
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