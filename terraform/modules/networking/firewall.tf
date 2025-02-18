resource "aws_networkfirewall_firewall_policy" "main" {
  name = "network-firewall-policy-1-${var.environment_name}"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe", "ForwardUnmatchedPacket"]
    stateless_fragment_default_actions = ["aws:drop", "DropUnmatchedFragment"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_main.arn
    }

    stateless_custom_action {
      action_definition {
        publish_metric_action {
          dimension {
            value = "ForwardUnmatchedPacket"
          }
        }
      }
      action_name = "ForwardUnmatchedPacket"
    }

    stateless_custom_action {
      action_definition {
        publish_metric_action {
          dimension {
            value = "DropUnmatchedFragment"
          }
        }
      }
      action_name = "DropUnmatchedFragment"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_main.arn
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "network-firewall-${var.environment_name}"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.main.id

  subnet_mapping {
    subnet_id = aws_subnet.firewall.id
  }
}

locals {
  tcp_protocol_number                    = 6
  udp_protocol_number                    = 17
  stateless_firewall_rule_group_capacity = 13
}

resource "aws_networkfirewall_rule_group" "stateless_main" {
  lifecycle {
    create_before_destroy = true
  }

  description = "Main stateless rule group for ${var.environment_name} environment firewall"
  capacity    = local.stateless_firewall_rule_group_capacity
  name        = "stateless-rules-cap-${local.stateless_firewall_rule_group_capacity}-${var.environment_name}"
  type        = "STATELESS"
  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        custom_action {
          action_definition {
            publish_metric_action {
              dimension {
                value = "DroppedIntraVPCTraffic"
              }
            }
          }
          action_name = "IntraVPCTrafficMetricAction"
        }

        # Drop intra-VPC traffic, that should never hit the firewall
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:drop", "IntraVPCTrafficMetricAction"]
            match_attributes {
              source {
                address_definition = aws_vpc.main.cidr_block
              }
              destination {
                address_definition = aws_vpc.main.cidr_block
              }
            }
          }
        }

        # Send HTTP(S) traffic to the stateful engine to filter
        # Outbound
        stateless_rule {
          priority = 2
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = local.isolated_cidr_10
              }
              source_port {
                from_port = 1024
                to_port   = 65535
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              destination_port {
                from_port = 80
                to_port   = 80
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }

        stateless_rule {
          priority = 3
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = local.private_cidr_10
              }
              source_port {
                from_port = 1024
                to_port   = 65535
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              destination_port {
                from_port = 80
                to_port   = 80
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }

        # Inbound
        stateless_rule {
          priority = 4
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              source_port {
                from_port = 443
                to_port   = 443
              }
              source_port {
                from_port = 80
                to_port   = 80
              }
              destination {
                address_definition = local.isolated_cidr_10
              }
              destination_port {
                from_port = 1024
                to_port   = 65535
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }

        # Inbound
        stateless_rule {
          priority = 5
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              source_port {
                from_port = 443
                to_port   = 443
              }
              source_port {
                from_port = 80
                to_port   = 80
              }
              destination {
                address_definition = local.private_cidr_10
              }
              destination_port {
                from_port = 1024
                to_port   = 65535
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }

        custom_action {
          action_definition {
            publish_metric_action {
              dimension {
                value = "DroppedNTP"
              }
            }
          }
          action_name = "DropNTPMetricAction"
        }

        # Drop NTP
        stateless_rule {
          priority = 6
          rule_definition {
            actions = ["aws:drop", "DropNTPMetricAction"]
            match_attributes {
              source {
                address_definition = local.private_cidr_10
              }
              source_port {
                from_port = 1024
                to_port   = 65535
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 123
                to_port   = 123
              }
              protocols = [local.tcp_protocol_number, local.udp_protocol_number]
            }
          }
        }

        stateless_rule {
          priority = 7
          rule_definition {
            actions = ["aws:drop", "DropNTPMetricAction"]
            match_attributes {
              source {
                address_definition = local.isolated_cidr_10
              }
              source_port {
                from_port = 1024
                to_port   = 65535
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 123
                to_port   = 123
              }
              protocols = [local.tcp_protocol_number, local.udp_protocol_number]
            }
          }
        }
      }
    }
  }
}

locals {
  firewall_config = {
    private_subnets = {
      cidr                 = local.private_cidr_10
      http_allowed_domains = []
      tls_allowed_domains = concat([
        ".clamav.net",    # to download virus definitions for ClamAV
        ".amazonaws.com", # to allow access to aws services that do not have explicit endpoints
        ],
        var.integration_domains
      )
      sid_offset = 100
    }
    isolated_subnets = {
      cidr                 = local.isolated_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 200
    }
  }

  # There is an open bug relating to the order of rule_options which prevents us from using the stateful_rule block, instead we need to assemble a suricata file dynamically
  # https://github.com/hashicorp/terraform-provider-aws/issues/35147
  # Solution below taken from https://github.com/communitiesuk/delta-common-infrastructure
  subnet_firewall_rules = [
    for name, config in local.firewall_config : join("\n", ["# ${name}",
      length(config.http_allowed_domains) == 0 && length(config.tls_allowed_domains) == 0 ?
      "drop ip ${config.cidr} any <> any any (msg:\"Drop all traffic from ${name}\"; sid:${config.sid_offset}; rev:1;)"
      : join("\n", concat(
        [
          for idx, http_domain in config.http_allowed_domains : startswith(http_domain, ".")
          ? "pass http ${config.cidr} [1024:] -> any 80 (http.host; content:\"${http_domain}\"; endswith; msg:\"Allow HTTP traffic from ${name} to *${http_domain}\"; flow:to_server; sid:${config.sid_offset + idx};)"
          : "pass http ${config.cidr} [1024:] -> any 80 (http.host; content:\"${http_domain}\"; startswith; endswith; msg:\"Allow HTTP traffic from ${name} to ${http_domain}\"; flow:to_server; sid:${config.sid_offset + idx};)"
        ],
        [
          for idx, tls_domain in config.tls_allowed_domains : startswith(tls_domain, ".")
          ? "pass tls ${config.cidr} [1024:] -> any 443 (tls.sni; content:\"${tls_domain}\"; nocase; endswith; msg:\"Allow TLS (HTTPS) traffic from ${name} to *${tls_domain}\"; flow:to_server; sid:${config.sid_offset + length(config.http_allowed_domains) + idx};)"
          : "pass tls ${config.cidr} [1024:] -> any 443 (tls.sni; content:\"${tls_domain}\"; startswith; nocase; endswith; msg:\"Allow TLS (HTTPS) traffic from ${name} to ${tls_domain}\"; flow:to_server; sid:${config.sid_offset + length(config.http_allowed_domains) + idx};)"
        ]
    ))]) if config != null
  ]

  base_firewall_rules = <<EOT
drop http any any -> any any (msg:"Drop HTTP traffic without allowlisted Host header"; sid:5001; rev:1;)
drop tls  any any -> any any (msg:"Drop TLS traffic without allowlisted SNI"; sid:5002; rev:1;)
drop tcp  any any -> any any (msg:"Drop remaining established TCP traffic"; flow:established; sid:5003; rev:1;)
# Drop other traffic
drop tcp  ${aws_vpc.main.cidr_block} any <> any ![80,443] (msg:"Drop TCP on ports except 80 and 443"; sid:5004; rev:1;)
drop ip   any any <> any any (msg:"Drop non-TCP traffic"; ip_proto:!TCP;sid:5005; rev:1;)
  EOT
  all_firewall_rules  = join("\n\n", [join("\n\n", local.subnet_firewall_rules), local.base_firewall_rules])
}

locals {
  stateful_firewall_group_capacity = 300
}

resource "aws_networkfirewall_rule_group" "stateful_main" {
  description = "Main stateful rule group for ${var.environment_name} environment firewall"
  capacity    = local.stateful_firewall_group_capacity
  name        = "stateful-rules-${local.stateful_firewall_group_capacity}-${var.environment_name}"
  type        = "STATEFUL"

  rules = local.all_firewall_rules

  lifecycle {
    create_before_destroy = true
  }
}