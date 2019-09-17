variable "loki_namespace" {
  type        = string
  description = "Namespace to deploy Loki into."
  default     = "logging"
}

variable "loki_namespace_create" {
  type        = bool
  description = "Whether to create the namespace to deploy Loki into or use an existing namespace for the deployment."
  default     = false
}

variable "loki_version" {
  type        = string
  description = "Version of Loki to deploy."
  default     = "0.3.0"
}

variable "loki_volume_claim_template_storage_class_name" {
  type = string
  description = "Volume class to use for storing Loki's stateful data."
  default = "default"
}

variable "loki_volume_claim_template_storage_request" {
  type = string
  description = "Amount of disk space to allocate for Loki's persistent data."
  default = "16Gi"
}
