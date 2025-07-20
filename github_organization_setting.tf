resource "github_organization_settings" "github_organization_settings_this_org" {
  billing_email = local.billing_email
  company       = local.company_name
  email         = local.email
  location      = "India"

  name        = local.name
  description = "This is a sample GitHub organization created using Terraform."

  default_repository_permission            = "none"
  members_can_create_repositories          = false
  members_can_create_public_repositories   = false
  members_can_create_private_repositories  = false
  members_can_create_internal_repositories = false

  members_can_create_pages         = false
  members_can_create_public_pages  = false
  members_can_create_private_pages = false

  members_can_fork_private_repositories = false
  web_commit_signoff_required           = false

  advanced_security_enabled_for_new_repositories = true
  dependency_graph_enabled_for_new_repositories  = true
  secret_scanning_enabled_for_new_repositories   = true

}