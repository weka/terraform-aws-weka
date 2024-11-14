output "scenario_handler_public_ip" {
  value = [for instance in aws_instance.cst_scenario_test : instance.private_ip]
}

resource "local_file" "scenario_handler_public_ip" {
  content  = join("\n", [for instance in aws_instance.cst_scenario_test : instance.public_ip])
  filename = "scenario_public_ip.txt"
}

