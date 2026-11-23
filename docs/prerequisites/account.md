# Account prerequisites

- Installer cluster on **OpenShift 5.0+** with baseline GitOps (External Secrets Operator).
- Azure **Cognitive Services** quota for OpenAI in the cluster region.
- Deployer: **Contributor** on customer RG; **Key Vault Secrets Officer** (or equivalent) on installer Key Vault for Terraform secrets.
- Ability to create subnets and Private Endpoints in the installer VNet.

Destroy the **agentic stack before** destroying the ARO HCP cluster.