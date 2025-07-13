# Terraform GitHub Organization Management

## Values to Replace

### providers.tf (or versions.tf)
- Review entire file and replace all placeholder values with actual values

### members.tf
- **Line 19**: Replace `["admin1", "admin2", "admin3"]` with actual admin usernames
- **Line 27**: Replace `["billing1", "billing2"]` with actual billing manager usernames

### Create members.tfvars.json
- Create this file with actual organization members
- Example format:
  ```json
  {
    "members": [
      "actual-username1",
      "actual-username2"
    ]
  }
  ```

