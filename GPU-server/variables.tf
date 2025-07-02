# -----------------------------------------------------
# Input Variable Declaration: instance_name
# -----------------------------------------------------
variable "instance_name" {
  # A human-readable explanation of what this variable is for.
  # In this case, it is used to set the 'Name' tag on the EC2 instance.
  description = "Value of the Name tag for the EC2 instance"

  # The expected type for this variable (a plain string).
  type = string

  # The default value to use if no value is provided in a .tfvars file
  # or via the command line. This means the variable is optional.
  default = "ExampleAppServerInstance"
}

# -----------------------------------------------------
# Input Variable Declaration: capacity_reservation_id
# -----------------------------------------------------
variable "capacity_reservation_id" {
  # A human-readable explanation of what this variable is for.
  # This variable holds the ID of an existing EC2 Capacity Reservation
  # that the EC2 instance should be launched into.
  #
  # If this variable is set to an empty string (default),
  # no capacity reservation will be used and the instance
  # will launch as a normal On-Demand instance without reservation.
  description = "The ID of the existing EC2 Capacity Reservation to use (empty string for none)"

  # The expected type for this variable (a plain string).
  type = string

  # Default value is empty string indicating no capacity reservation.
  default = ""
}
