# Dashboard List de la status page interne. Elle contient tous les dashboards
# de ../dashboards : un dashboard supprime puis recree (nouvel identifiant)
# reste donc dans la liste, sans geste manuel.
#
# Le type d'un element depend de la mise en page du dashboard : "free" donne
# un screenboard, "ordered" un timeboard. Il est lu dans le JSON lui-meme.

locals {
  dashboard_layouts = {
    for f in fileset("${path.module}/../dashboards", "*.json") :
    f => jsondecode(file("${path.module}/../dashboards/${f}")).layout_type
  }
}

resource "datadog_dashboard_list" "status_page" {
  name = "Volontariapp"

  dynamic "dash_item" {
    for_each = datadog_dashboard_json.all
    content {
      type    = local.dashboard_layouts[dash_item.key] == "free" ? "custom_screenboard" : "custom_timeboard"
      dash_id = dash_item.value.id
    }
  }
}
