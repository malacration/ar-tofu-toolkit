locals {
  vpc_mode = length(var.network.subnet_ids) > 0

  effective_engine_version = split("_", var.engine_version)[1]

  endpoint_url = "https://${aws_opensearch_domain.this.endpoint}"

  fluentbit_output_config = <<-EOT
[OUTPUT]
    Name              es
    Match             *
    Host              ${aws_opensearch_domain.this.endpoint}
    Port              443
    TLS               On
    TLS.Verify        On
    HTTP_User         ${var.master_user.username}
    HTTP_Passwd       ${var.master_user.password}
    Logstash_Format   On
    Logstash_Prefix   ${var.log_index}
    Logstash_DateFormat ${var.log_index_date_format}
    Type              _doc
    Suppress_Type_Name On
    Retry_Limit       False
    Replace_Dots      On
EOT
}
