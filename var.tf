variable "key" {
  type = string
}
variable "secret" {
  type = string
  sensitive = true
}
variable "host" {
  type = string
}