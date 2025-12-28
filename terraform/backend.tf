terraform {
  backend "s3" {
    bucket = "travelease-contact1700-state-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
