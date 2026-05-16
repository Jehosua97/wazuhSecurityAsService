terraform {
  backend "gcs" {
    bucket = "wazuh-security-service-tfstate-wazuh-iac-on-gcp"
    prefix = "terraform/wazuh-deploy"
  }
}
