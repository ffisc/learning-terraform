# variables are handy for keeping together things that may change often
variable "instance_type" {
 description = "Type of EC2 instance to provision"
 default     = "t3.nano"
}
