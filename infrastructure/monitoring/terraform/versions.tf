terraform {
  required_version = ">= 1.5"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.29"
    }
  }
}
