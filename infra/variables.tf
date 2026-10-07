variable "environment" {
  type        = string
}

variable "api_name" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "app_base_url" {
  type        = string
}

# lambdas do ambiente (repo g52-lambda-tech-challenge), viram stage variables
variable "auth_function_name" {
  type        = string
}

variable "authorizer_function_name" {
  type        = string
}

variable "mailpit_base_url" {
  type        = string
}

variable "aws_account" {
  type        = string
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  type        = number
  default     = 1
}

variable "destroy" {
  type        = bool
  default     = false
}