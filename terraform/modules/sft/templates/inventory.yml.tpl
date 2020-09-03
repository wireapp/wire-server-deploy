sft_servers:
  hosts:
  %{~ for instance in instances ~}
    ${ instance.hostname }:
      ansible_host: '${ instance.ipaddress }'
      ansible_ssh_user: root
      ansible_python_interpreter: /usr/bin/python3

      sft_fqdn: '${ instance.fqdn }'

      announcer_zone_domain: '${ zoneDomain }'
      announcer_aws_key_id: '${ awsKeyID }'
      announcer_aws_access_key: '${ awsAccessKey }'
      announcer_aws_region: '${ awsRegion }'

      announcer_srv_records:
        sft:
          name: '_sft._tcp.${ env }'
          target: '${ instance.fqdn }'
  %{~ endfor ~}