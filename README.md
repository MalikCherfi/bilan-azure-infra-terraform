# bilan-azure-infra-terraform

# bilan-azure-infra-terraform

Infra Azure (AKS partagé, PostgreSQL, Redis, ACR, Storage, Key Vault) déployée via Terraform + OIDC GitHub Actions.

## Ressources créées
- Key Vault (secrets centralisés)
- PostgreSQL Flexible Server + DB
- Redis (Managed Redis)
- Storage Account + container + SAS
- Container Registry (ACR) + rôle AcrPull pour AKS
- Ingress-nginx (Helm) sur le cluster AKS partagé

## Prérequis
- Azure CLI + Terraform ≥ 1.9
- Backend distant (state) : `bootstrap-backend.sh`
- Identité fédérée GitHub OIDC : `setup-federated-identity.sh`

## Déploiement
```bash
terraform init
terraform plan
terraform apply
```

Ou via GitHub Actions : workflow `Terraform workflow dispatch` (`apply` / `destroy`).

## Variables requises
`owner`, `resource_group_name`, `location`, `plan_name`, `node_resource_group_name`, `cluster_name`

## Secrets GitHub
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_SA_NAME`, `AZURE_CONTAINER_NAME`, `TFSTATE_KEY`