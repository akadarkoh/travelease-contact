variable "bucket_name" {
  type    = string
  default = "travelease-contact-bucket-1700"
}

variable "form_completion" {
  type    = string
  default = "production"
}

variable "processing" {
  type    = string
  default = "production"
}

variable "communications" {
  type    = string
  default = "production"
}

variable "region" { 
  type    = string
  default = "us-east-1"
}

variable "from_email"{
  type = string
  default = "change-me@example.com"
}

variable "admin_email" {
  type = string
  default = "change-me@example.com"
}

variable "company_email" {
  type = string
  default = "change-me@example.com"
}