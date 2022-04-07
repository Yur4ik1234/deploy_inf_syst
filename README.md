
# deploy_inf_syst

It is a project of automation deploying service.

## What I use

- Terraform for creation infrasrtucture
- Azure as a Terraform provider
- Ansible playbooks for configuration managment 

In *main.tf* I wrote down all infrasructure which includes:
1. Azure Scale set (which gives opportunity to easy scaling our servers)
2. Loadbalancer

In */ansible/playbook.yml* I deploy a docker container in my scale set

