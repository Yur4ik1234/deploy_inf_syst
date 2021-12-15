#!/bin/bash

terraform init

ssh-keygen -t rsa


terraform apply -auto-approve 

ansible-playbook -i hosts.txt ansible/playbook.yaml