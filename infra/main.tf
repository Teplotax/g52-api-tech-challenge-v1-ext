# rest api criado no g52-infra-gateway-tech-challenge; busca pelo nome pra não fixar o id
data "aws_api_gateway_rest_api" "this" {
  name = var.api_name
}

resource "aws_cloudwatch_log_group" "apigw_stage" {
  name              = "/aws/apigateway/${var.api_name}/${var.environment}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# rotas (inclusive /mailpit) vêm do openapi importado no pipeline; aqui só o stage do ambiente
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = data.aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(file("${path.module}/openapi-resolved.json"))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = data.aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment

  # destino de cada stage: app (nlb), mailpit e lambdas do ambiente
  variables = {
    appHost            = replace(var.app_base_url, "/^https?:\\/\\//", "")
    mailpitHost        = replace(var.mailpit_base_url, "/^https?:\\/\\//", "")
    authFunction       = var.auth_function_name
    authorizerFunction = var.authorizer_function_name
    stage              = var.environment
  }

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

# saíram daqui: a role de log da conta foi pro g52-infra-gateway (é uma só pros 3 stages)
# e o /mailpit foi pro openapi. removed tira do state do dev sem apagar na aws
removed {
  from = aws_iam_role.apigw_cloudwatch
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.apigw_cloudwatch
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_account.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_resource.mailpit
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_resource.mailpit_proxy
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_method.mailpit_root
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_integration.mailpit_root
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_method.mailpit_proxy
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_api_gateway_integration.mailpit_proxy
  lifecycle {
    destroy = false
  }
}
