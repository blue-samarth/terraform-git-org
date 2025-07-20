locals {
  repo_names = flatten([
    for root_team in var.root_teams : [
      for subteam in root_team.subteams :
      "${lower(root_team.abbreviation)}-${lower(replace(subteam.name, " ", "-"))}-service"
    ]
  ])
}

resource "github_repository" "repositories" {
  for_each = toset(local.repo_names)

  # Basic repository settings
  name        = each.key
  visibility  = "private"
  description = "Repository for ${each.key}"

  # Repository features
  has_issues      = true
  has_projects    = true
  has_wiki        = false
  has_discussions = false
  has_downloads   = true
  auto_init       = true

  # Branch and template settings
  default_branch     = ["development", "production", "staging"][0]
  gitignore_template = null

  # Merge configuration
  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true
  allow_auto_merge       = true
  allow_update_branch    = true

  # Security and maintenance
  archive_on_destroy = true

  depends_on = [github_organization_settings.github_organization_settings_this_org]
}