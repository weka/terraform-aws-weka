resource "local_file" "scenario_handler_public_ip" {
  content  = aws_instance.cst_scenario_specialty.public_ip
  filename = "scenario_public_ip.txt"
}
