output "status" {
  value = helm_release.consul.status
}
output "name" {
  value = helm_release.consul.name
}
output "version" {
  value = helm_release.consul.version
}
output "values" {
  value = helm_release.consul.values
}
