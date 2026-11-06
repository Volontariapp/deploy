terraform {
  required_version = "1.17.1"

  # Le state vit dans HCP Terraform. Le workspace est en execution locale :
  # Terraform tourne dans la CI GitHub, HCP ne fait que garder le state.
  cloud {
    organization = "Volontariapp"

    workspaces {
      name = "Volontariapp-deploy"
    }
  }

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.29"
    }
  }
}
