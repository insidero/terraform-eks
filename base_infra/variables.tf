variable "cidr" {
}

variable "availability_zones" {
  type = list(string)
}

variable "region" {
  type        = string
  default="us-east-2"
}