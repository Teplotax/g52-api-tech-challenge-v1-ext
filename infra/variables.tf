variable "environment" {
  type        = string
}

variable "api_name" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "apigateway_id" {
  type        = string
}

variable "loadBalancerDnsMain" {
  type        = string
}


variable "aws_account" {
  type        = string
}

variable "aws_region" {
  type        = string
  default     = "sa-east-1"
}

variable "log_retention_days" {
  type        = number
  default     = 1
}

variable "destroy" {
  type        = bool
  default     = false
}