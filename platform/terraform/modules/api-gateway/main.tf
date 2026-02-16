resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project}-${var.environment}-api"
  description = "REST API Gateway for ${var.project} ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-api"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_api_gateway_vpc_link" "main" {
  name        = "${var.project}-${var.environment}-vpc-link"
  target_arns = [var.nlb_arn]

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-vpc-link"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://backend.internal/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_integration.proxy.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${var.stage_name}"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project}-${var.environment}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
    metrics_enabled        = true
    logging_level          = "INFO"
  }
}
