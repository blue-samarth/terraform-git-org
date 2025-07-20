locals {
  # Create all repo-branch combinations
  environment_branches = flatten([
    for repo_name in local.repo_names : [
      for branch in ["production", "staging"] : {
        key        = "${repo_name}-${branch}"
        repository = repo_name
        branch     = branch
      }
    ]
  ])
  environment_branches_map = {
    for combo in local.environment_branches : combo.key => combo
  }
}

resource "github_branch" "environment_branches" {
  for_each = local.environment_branches_map

  repository = github_repository.repositories[each.value.repository].name
  branch     = each.value.branch

  depends_on = [github_repository.repositories]
}