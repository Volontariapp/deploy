# Une ressource par fichier JSON : ajouter un fichier dans dashboards/ ou
# monitors/ suffit a le creer, en supprimer un le detruit cote Datadog.
# La cle du for_each est le nom du fichier (ex. "async-flows.json"), c'est elle
# que `terraform import` doit utiliser pour rattacher un objet existant.

resource "datadog_dashboard_json" "all" {
  for_each  = fileset("${path.module}/../dashboards", "*.json")
  dashboard = file("${path.module}/../dashboards/${each.value}")
}

resource "datadog_monitor_json" "all" {
  for_each = fileset("${path.module}/../monitors", "*.json")
  monitor  = file("${path.module}/../monitors/${each.value}")
}
