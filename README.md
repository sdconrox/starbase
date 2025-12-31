# Starbase

An Ansible-based infrastructure automation project for deploying and managing an AWS EKS (Elastic Kubernetes Service) cluster.

## Overview

Starbase is an infrastructure-as-code project that automates the deployment of a Kubernetes cluster on AWS using EKS. The project uses Ansible playbooks to provision AWS infrastructure components including VPCs, EKS clusters, node groups, and IAM configurations.

## Project Structure

```
starbase/
├── playbooks/           # Ansible playbooks
│   └── starbase.yml     # Main playbook for cluster deployment
├── roles/               # Ansible roles
│   ├── common/          # Common variables and settings
│   ├── iam/             # IAM role and policy management
│   ├── infrastructure/  # AWS infrastructure provisioning (VPC, EKS, node groups)
│   └── services/        # Kubernetes service deployments (Vault, cert-manager, MySQL)
├── bin/                 # Utility scripts
│   └── aws-vpc-scan.sh  # AWS VPC resource scanning script
├── lib/                 # Library files
├── var/                 # Variable files and logs
│   └── log/             # Ansible execution logs
├── entertainment/       # Additional tasks and templates
├── starbase.sh          # Main shell script with EKS setup commands
├── starbase.py          # Python script for ansible-runner integration
├── ansible.cfg          # Ansible configuration
├── inventory            # Ansible inventory file
├── cluster_keys.json    # Cluster key configuration
├── ebs-csi-iam-policy.json  # EBS CSI driver IAM policy
└── 20210804-aws-com_sdconrox-hosted_zone.json  # Route53 hosted zone configuration
```

## Key Components

### Main Playbook (`playbooks/starbase.yml`)
The primary playbook that orchestrates the deployment:
- Executes common role for variable initialization
- Deploys IAM components
- Deploys services (currently includes commented-out Istio, Vault, cert-manager, and MySQL configurations)

### Ansible Roles

1. **common**: Defines common variables including:
   - AWS region and profile settings
   - EKS cluster configuration (name: `starbase`, Kubernetes version: 1.17)
   - Node group settings (t3.medium instances, 3 nodes)
   - WordPress and Route53 domain settings

2. **iam**: Manages AWS Identity and Access Management components

3. **infrastructure**: Provisions AWS infrastructure via CloudFormation:
   - VPC creation
   - EKS cluster deployment
   - EKS node group creation

4. **services**: Handles Kubernetes service deployments (currently commented out):
   - HashiCorp Vault
   - cert-manager
   - MySQL (via Bitnami Helm charts)

### Utility Scripts

- **starbase.sh**: Shell script containing AWS EKS setup commands and documentation, including:
  - EKS cluster configuration
  - EBS CSI driver setup instructions
  - kubeconfig creation commands

- **bin/aws-vpc-scan.sh**: Script to scan and list AWS VPC resources including:
  - Internet gateways
  - Subnets
  - Route tables
  - Network ACLs
  - Security groups
  - NAT gateways
  - VPN connections
  - And other VPC-related resources

### Configuration Files

- **ansible.cfg**: Ansible configuration specifying:
  - User: `sdconrox`
  - Python interpreter: `/usr/bin/env python3`
  - Inventory and playbook directories
  - Roles path and log location

- **inventory**: Ansible inventory file configured for localhost execution

- **ebs-csi-iam-policy.json**: IAM policy for Amazon EBS CSI driver

- **cluster_keys.json**: Cluster key configuration data

## Prerequisites

- Ansible installed and configured
- AWS CLI configured with appropriate credentials
- Python 3
- kubectl (for Kubernetes operations)
- eksctl (for EKS cluster management)
- Helm (for service deployments)

## Usage

1. Configure AWS credentials and profile (`sdconrox_api` profile)
2. Update variables in `roles/common/vars/main.yml` as needed
3. Run the main playbook:
   ```bash
   ansible-playbook playbooks/starbase.yml
   ```

## AWS Resources

The project deploys the following AWS resources:
- VPC with networking components
- EKS cluster named `starbase`
- EKS node group with 3 t3.medium instances
- IAM roles and policies for cluster and node group operations
- EBS CSI driver IAM policy for persistent volume support

## Notes

- The project uses CloudFormation templates (referenced in the infrastructure role) for resource provisioning
- Some service deployments (Vault, cert-manager, MySQL) are currently commented out in the services role
- The project is configured for the `us-east-1` AWS region
- Kubernetes version 1.17 is specified (may need updating for current EKS support)
