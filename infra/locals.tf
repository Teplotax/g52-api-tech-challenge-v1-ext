locals {
  project = "template"
  squad   = "grupo-52"
  sigla   = "g52"

  common_tags = {
    environment = var.environment
    squad       = local.squad
    sigla       = local.sigla
    project     = local.project
  }
}