#---variable/root

variable "zone_id" {
  type    = string
  default = ""
}

variable "name" {
  type    = string
  default = "augustovaldivia.ca"
}

variable "region_number" {
  # Arbitrary mapping of region name to number to use in
  # a VPC's CIDR prefix.
  default = {
    us-west-2 = 1
    us-west-1 = 2
    us-east-1 = 3

  }
}

variable "az_number" {
  # Assign a number to each AZ letter used in our configuration
  default = {
    a = 1
    b = 2
    c = 3
    d = 4
    e = 5
    f = 6
  }
}