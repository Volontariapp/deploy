# Les cles ne sont jamais ecrites ici : le provider lit DD_API_KEY et DD_APP_KEY
# dans l'environnement (secrets GitHub du repo en CI, export local sinon).
variable "datadog_api_url" {
  type        = string
  description = "URL de l'API du site Datadog, sans /api/ final."
  default     = "https://api.us5.datadoghq.com/"
}

provider "datadog" {
  api_url = var.datadog_api_url
}
