# Here we will add the configurations to add members to the organization only at the moment.
# the other values role can be "member" or "admin" or "billing_manager" or "owner"
# Admins and billing managers are defined directly in resources for separation from regular members

variable "members" {
  description = "List of GitHub organization members"
  type        = set(string)
  default     = []
  validation {
    condition = alltrue([
      for username in var.members : can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-])*[a-zA-Z0-9]$", username))
    ])
    error_message = "Invalid GitHub username format."
  }
}


resource "github_membership" "admins" {
  for_each = toset(["admin1", "admin2", "admin3"]) # Replace with actual GitHub usernames
  username = each.value
  role     = "admin"

  downgrade_allowed = true # Allows downgrading from admin to member
}

resource "github_membership" "billing_managers" {
  for_each = toset(["billing1", "billing2"]) # Replace with actual GitHub usernames
  username = each.value
  role     = "billing_manager"

  downgrade_allowed = true # Allows downgrading from billing manager to member
}

resource "github_membership" "members" {
  for_each = var.members
  username = each.value
  role     = "member"
}