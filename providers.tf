locals {
  name           = "organization-name"
  org_short_name = "org-short-name"

  region = "ap-south-2"

  environment     = "production"
  organization_id = "org-1234567890"
  billing_account = "billing-1234567890"
  billing_email   = "billing@example.com"
  company_name    = "Example Company"
  email           = "user@example.com"
}

provider "github" {
  owner = local.org_short_name
  token = "<YOUR_GITHUB_TOKEN>"
}