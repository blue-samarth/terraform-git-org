# Here we will handle the github teams as well as the subteams under those teams.
# The root team will have several daughter teams.

variable "root_teams" {
  description = "GitHub organization teams with hierarchical structure"
  type = list(object({
    name        = string
    description = string
    privacy     = string
    subteams = optional(list(object({
      name        = string
      description = string
      privacy     = string
    })), [])
  }))
  default = []
  validation {
    condition = alltrue([
      for team in var.root_teams : contains(["closed", "secret"], team.privacy)
    ])
    error_message = "Team privacy must be either 'closed' or 'secret'."
  }
  validation {
    condition = alltrue([
      for team in var.root_teams : alltrue([
        for subteam in team.subteams : contains(["closed", "secret"], subteam.privacy)
      ])
    ])
    error_message = "Subteam privacy must be either 'closed' or 'secret'."
  }
}

resource "github_team" "root_teams" {
  for_each = {
    for team in var.root_teams : team.name => team
  }

  name        = each.value.name
  description = each.value.description
  privacy     = each.value.privacy
}

locals {
  subteams = flatten([
    for team in var.root_teams : [
      for subteam in team.subteams : {
        name        = subteam.name
        description = subteam.description
        privacy     = subteam.privacy
        parent_team = team.name
      }
    ]
  ])
}

resource "github_team" "subteams" {
  for_each = {
    for subteam in local.subteams : "${subteam.parent_team}-${subteam.name}" => subteam
  }

  name           = each.value.name
  description    = each.value.description
  privacy        = each.value.privacy
  parent_team_id = github_team.root-teams[each.value.parent_team].id
}