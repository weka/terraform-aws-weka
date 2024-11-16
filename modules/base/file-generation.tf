# Collect all private IPs into a list
output "private_ips" {
  value = [for instance in aws_instance.cst_scenario_backend : instance.private_ip]
}

# Collect all public IPs into a list
output "public_ips" {
  value = [for instance in aws_instance.cst_scenario_backend : instance.public_ip]
}

# Create a file with private IPs
resource "local_file" "private_backends" {
  content  = join("\n", [for instance in aws_instance.cst_scenario_backend : instance.private_ip])
  filename = "private-backends.txt"
}

# Create a file with public IPs
resource "local_file" "public_backends" {
  content  = join("\n", [for instance in aws_instance.cst_scenario_backend : instance.public_ip])
  filename = "public-backends.txt"
}
# Create a file with client public IPs
resource "local_file" "public_clients" {
  content  = join("\n", [for instance in aws_instance.cst_scenario_client : instance.public_ip])
  filename = "public-clients.txt"
}
resource "local_file" "autodestroy_private_key" {
  content  = tls_private_key.autodestroy_key.private_key_pem
  filename = "./${random_pet.fun-name.id}-key.pem"
  file_permission = "0600"  # Set secure permissions
}

