terraform {
  required_providers {
    secureworkload = {
      source = "CiscoDevNet/secureworkload"
    }
  }
}
provider "secureworkload" {
  api_key                  = var.key
  api_secret               = var.secret
  api_url                  = var.host
  disable_tls_verification = true
}

################################################################################################
# Step-1:  Labelling
################################################################################################
resource "secureworkload_label" "label-1" {
    ip = "10.0.23.0/24"
    root_scope_name = "CSW-TME"
    attributes = {
        organization = "cisco"
        location = "datacenter"
        environment = "production"
        application = "CiscoLiveDemo"
    }
}
resource "secureworkload_label" "label-2" {
    ip = "10.0.21.0/24"
    root_scope_name = "CSW-TME"
    attributes = {
        organization = "cisco"
        location = "datacenter"
        environment = "production"
        application = "CiscoLiveDemo"
    }
}
resource "secureworkload_label" "label-3" {
    ip = "10.0.25.0/24"
    root_scope_name = "CSW-TME"
    attributes = {
        organization = "cisco"
        location = "datacenter"
        environment = "production"
        application = "CiscoLiveDemo"
    }
}

################################################################################################
# Step-2: Scopes and Workspace
################################################################################################
data "secureworkload_scope" "scope" {
    depends_on = [ time_sleep.wait_10_seconds5 ]
    exact_name = "CSW-TME:AcmeCorp:Datacenter:Production"
}
resource "secureworkload_scope" "cl24" {
    depends_on = [ time_sleep.wait_10_seconds5 ]
    short_name = "CiscoLive 2024"
    short_query = file("${path.module}/query_file.json") 
    parent_app_scope_id = data.secureworkload_scope.scope.id
}
resource "secureworkload_workspace" "workspace" {
  depends_on = [ time_sleep.wait_10_seconds5 ]
  app_scope_id         = secureworkload_scope.cl24.id
  name                 = "Melbourne24 App"
  description          = "A testing workspace for Cisco Live Demo"
}

################################################################################################
# Step-3: Clusters & Filters
################################################################################################
resource "secureworkload_cluster" "app" {
  depends_on = [ time_sleep.wait_10_seconds6 ]
  workspace_id = secureworkload_workspace.workspace.id
  name = "app-tier"
  description = "Testing feature"
  approved = false
  query = <<EOF
                {
                 "type":"subnet",
                 "field": "ip",
                 "value": "10.0.23.0/24"
                 }
            EOF
}
resource "secureworkload_cluster" "db" {
  depends_on = [ time_sleep.wait_10_seconds6 ]
  workspace_id = secureworkload_workspace.workspace.id
  name = "db-tier"
  description = "Testing feature"
  approved = false
  query = <<EOF
                {
                 "type":"eq",
                 "field": "ip",
                 "value": "10.0.25.10"
                 }
            EOF
}

resource "secureworkload_cluster" "web" {
  depends_on = [ time_sleep.wait_10_seconds4 ]
  workspace_id = secureworkload_workspace.workspace.id
  name = "web-tier"
  description = "Testing feature"
  approved = false
  query = <<EOF
                {
                 "type":"eq",
                 "field": "ip",
                 "value": "10.0.21.10"
                 }
            EOF
}

data "secureworkload_scope" "csw_tme" {
    depends_on = [ time_sleep.wait_10_seconds5 ]
    exact_name = "CSW-TME"
}
resource "secureworkload_filter" "user" {
    depends_on = [ time_sleep.wait_10_seconds4 ]
    app_scope_id = data.secureworkload_scope.csw_tme.id
    name = "external-user"
    query = <<EOF
                {
                 "type":  "subnet",
                 "field": "ip",
                 "value": "72.163.220.0/24"
                 }
            EOF
    primary = true 
    public = false 
}
################################################################################################
# Step-4: Policy Creation
################################################################################################

resource "secureworkload_policies" "web2app" {
  depends_on = [ time_sleep.wait_10_seconds ]
  workspace_id = secureworkload_workspace.workspace.id
  consumer_filter_id = secureworkload_cluster.web.id
  provider_filter_id = secureworkload_cluster.app.id
  policy_action = "ALLOW"
}
resource "secureworkload_port" "web2app" {
  depends_on = [ time_sleep.wait_10_seconds ]
  policy_id = secureworkload_policies.web2app.id
  start_port= 8989
  end_port= 8997
  proto = 6
}
resource "secureworkload_policies" "app2db" {
  depends_on = [ time_sleep.wait_10_seconds2 ]
  workspace_id = secureworkload_workspace.workspace.id
  consumer_filter_id = secureworkload_cluster.app.id
  provider_filter_id = secureworkload_cluster.db.id
  policy_action = "ALLOW"
}
resource "secureworkload_port" "app2db" {
  depends_on = [ time_sleep.wait_10_seconds2 ]
  policy_id = secureworkload_policies.app2db.id
  start_port= 3306
  end_port= 3306
  proto = 6
}
resource "secureworkload_port" "app2db2" {
  depends_on = [ secureworkload_port.app2db ]
  policy_id = secureworkload_policies.app2db.id
  start_port= 8998
  end_port= 8998
  proto = 6
}

resource "secureworkload_policies" "user2web" {
  depends_on = [ time_sleep.wait_10_seconds3 ]
  workspace_id = secureworkload_workspace.workspace.id
  consumer_filter_id = secureworkload_filter.user.id
  provider_filter_id = secureworkload_cluster.web.id
  policy_action = "ALLOW"
}
resource "secureworkload_port" "user2web" {
  depends_on = [ time_sleep.wait_10_seconds3 ]
  policy_id = secureworkload_policies.user2web.id
  start_port= 8080
  end_port= 8080
  proto = 6
}
################################################################################################
# Step-5: Policy Enforcement
################################################################################################

resource "secureworkload_enforce" "enforced" {
  depends_on = [  secureworkload_port.user2web, secureworkload_port.web2app,  secureworkload_port.app2db, secureworkload_port.app2db2 ]
  workspace_id = secureworkload_workspace.workspace.id
}















################################################################################################
# Wait Code
################################################################################################
resource "time_sleep" "wait_10_seconds6" {
  depends_on = [secureworkload_workspace.workspace]
  create_duration = "10s"
}

resource "time_sleep" "wait_10_seconds5" {
  depends_on = [secureworkload_label.label-1, secureworkload_label.label-2, secureworkload_label.label-3]
  create_duration = "10s"
}
resource "time_sleep" "wait_10_seconds4" {
  depends_on = [secureworkload_cluster.app, secureworkload_cluster.db ]
  create_duration = "10s"
}
resource "time_sleep" "wait_10_seconds3" {
  depends_on = [secureworkload_port.app2db2 ]
  create_duration = "10s"
}
resource "time_sleep" "wait_10_seconds2" {
  depends_on = [secureworkload_policies.web2app,secureworkload_port.web2app ]
  create_duration = "10s"
}
resource "time_sleep" "wait_10_seconds" {
  depends_on = [secureworkload_cluster.web,secureworkload_cluster.app, secureworkload_cluster.db ]
  create_duration = "10s"
}