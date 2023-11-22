# output "webserver_public_ip" {
#   value = aws_eip.web_instance_eip[0].public_ip
# #   
# # }

# # output "webserver_public_dns" {
# #   value = aws_eip.web_instance_eip[0].public_dns
# #   depends_on = [aws_instance.web_instance_eip]
# # }

output "db_endpoint" {
  value = aws_db_instance.database.address
}

output "db_port" {
  value = aws_db_instance.database.port
}