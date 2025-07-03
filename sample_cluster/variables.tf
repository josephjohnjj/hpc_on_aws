variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ExampleAppServerInstance"
}

variable "node_count" {
  description = "Number of EC2 instances to create in the cluster"
  type        = number
  default     = 3
}