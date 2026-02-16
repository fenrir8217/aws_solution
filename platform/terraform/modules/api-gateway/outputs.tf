output "api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "invoke_url" {
  description = "Invoke URL for the API stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.main.stage_name
}

output "vpc_link_id" {
  description = "ID of the VPC link"
  value       = aws_api_gateway_vpc_link.main.id
}
