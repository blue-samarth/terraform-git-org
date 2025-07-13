#!/bin/bash

# Script to generate team members JSON structure from Terraform configuration files
# This script parses Terraform configuration files to extract team definitions and creates a JSON template for team membership

set -e

# Configuration
TERRAFORM_DIR="."
OUTPUT_FILE="team_members.tfvars.json"
TEAMS_CONFIG_FILE="teams.tfvars.json"
TEMP_FILE=$(mktemp)

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: The following required tools are missing: ${missing_tools[*]}"
        echo "Please install jq and try again."
        exit 1
    fi
}

# Function to validate Terraform configuration file exists
validate_config_file() {
    if [ ! -f "$TEAMS_CONFIG_FILE" ]; then
        echo "Error: Teams configuration file '$TEAMS_CONFIG_FILE' not found."
        echo "Please ensure your teams.tfvars.json file exists in the current directory."
        exit 1
    fi
    
    # Validate JSON structure
    if ! jq empty "$TEAMS_CONFIG_FILE" 2>/dev/null; then
        echo "Error: Invalid JSON format in '$TEAMS_CONFIG_FILE'."
        echo "Please verify the file contains valid JSON."
        exit 1
    fi
    
    # Check for required root_teams structure
    if ! jq -e '.root_teams' "$TEAMS_CONFIG_FILE" >/dev/null 2>&1; then
        echo "Error: 'root_teams' key not found in '$TEAMS_CONFIG_FILE'."
        echo "Please ensure your configuration file contains the root_teams array."
        exit 1
    fi
}

# Function to extract team information from Terraform configuration
extract_teams_from_config() {
    echo "Extracting team information from Terraform configuration..."
    
    # Extract root teams and create members structure
    local root_teams
    root_teams=$(jq -r '
        .root_teams[] |
        {
            name: .name,
            members: []
        }
    ' "$TEAMS_CONFIG_FILE" | jq -s '.')
    
    # Extract subteams and create members structure with parent team info
    local subteams
    subteams=$(jq -r '
        .root_teams[] as $parent |
        $parent.subteams[]? |
        {
            name: .name,
            parent_team: $parent.name,
            members: []
        }
    ' "$TEAMS_CONFIG_FILE" | jq -s '.')
    
    # Create the final JSON structure
    jq -n \
        --argjson root_teams "$root_teams" \
        --argjson subteams "$subteams" \
        '{
            "root-teams": $root_teams,
            "subteams": $subteams
        }' > "$OUTPUT_FILE"
}

# Function to parse Terraform HCL files if JSON config is not available
parse_terraform_files() {
    echo "Searching for team definitions in Terraform files..."
    
    # Look for .tf files containing team definitions
    local tf_files
    tf_files=$(find "$TERRAFORM_DIR" -name "*.tf" -type f)
    
    if [ -z "$tf_files" ]; then
        echo "Error: No Terraform files found in directory '$TERRAFORM_DIR'."
        exit 1
    fi
    
    # Create temporary JSON structure
    echo '{"root_teams": []}' > "$TEMP_FILE"
    
    # Parse each .tf file for variable definitions
    while IFS= read -r tf_file; do
        if grep -q "variable.*root_teams" "$tf_file"; then
            echo "Found team variable definition in: $tf_file"
            echo "Please ensure you have a corresponding teams.tfvars.json file with team definitions."
            echo "This script requires the actual team data from your variable files, not just the variable declarations."
            exit 1
        fi
    done <<< "$tf_files"
    
    echo "Error: No team configuration data found. Please provide a teams.tfvars.json file."
    exit 1
}

# Function to validate and format the output
validate_output() {
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Validating generated JSON structure..."
        
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            echo "JSON structure is valid."
            
            # Pretty print the output
            jq '.' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
            
            # Display summary
            local root_count subteam_count
            root_count=$(jq '.["root-teams"] | length' "$OUTPUT_FILE")
            subteam_count=$(jq '.subteams | length' "$OUTPUT_FILE")
            
            echo "Generated team members template:"
            echo "- Root teams: $root_count"
            echo "- Subteams: $subteam_count"
            echo "- Output file: $OUTPUT_FILE"
            
            # Show preview of generated structure
            echo ""
            echo "Preview of generated structure:"
            jq '.' "$OUTPUT_FILE"
        else
            echo "Error: Generated JSON is invalid."
            exit 1
        fi
    else
        echo "Error: Output file was not created."
        exit 1
    fi
}

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script generates a JSON template for team membership based on existing
Terraform team configuration. It reads team definitions from your teams.tfvars.json
file and creates a structure ready for populating with team members.

OPTIONS:
    -h, --help      Show this help message
    -o, --output    Specify output file (default: team_members.tfvars.json)
    -d, --dir       Specify Terraform directory (default: current directory)
    -c, --config    Specify teams config file (default: teams.tfvars.json)

EXAMPLES:
    $0                                          # Generate with default settings
    $0 -o custom_teams.json                    # Specify custom output file
    $0 -d /path/to/terraform                   # Specify Terraform directory
    $0 -c my_teams.tfvars.json                 # Specify custom config file

REQUIREMENTS:
    - jq command line JSON processor
    - teams.tfvars.json file with team definitions

INPUT FILE FORMAT:
    The script expects a teams.tfvars.json file with the following structure:
    {
        "root_teams": [
            {
                "name": "Team Name",
                "description": "Team Description",
                "privacy": "closed",
                "subteams": [
                    {
                        "name": "Subteam Name",
                        "description": "Subteam Description",
                        "privacy": "closed"
                    }
                ]
            }
        ]
    }

OUTPUT FORMAT:
    The script generates a file with the following structure:
    {
        "root-teams": [
            {
                "name": "Team Name",
                "members": []
            }
        ],
        "subteams": [
            {
                "name": "Subteam Name",
                "parent_team": "Parent Team Name",
                "members": []
            }
        ]
    }

EOF
}

# Main execution function
main() {
    local terraform_dir="$TERRAFORM_DIR"
    local output_file="$OUTPUT_FILE"
    local config_file="$TEAMS_CONFIG_FILE"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -d|--dir)
                terraform_dir="$2"
                shift 2
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Update global variables
    TERRAFORM_DIR="$terraform_dir"
    OUTPUT_FILE="$output_file"
    TEAMS_CONFIG_FILE="$config_file"
    
    # Change to Terraform directory
    cd "$TERRAFORM_DIR" || {
        echo "Error: Cannot access directory $TERRAFORM_DIR"
        exit 1
    }
    
    echo "Team Members JSON Generator"
    echo "==========================="
    echo "Working directory: $(pwd)"
    echo "Config file: $TEAMS_CONFIG_FILE"
    echo "Output file: $OUTPUT_FILE"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Validate configuration file exists and has correct structure
    validate_config_file
    
    # Extract teams from configuration
    extract_teams_from_config
    
    # Validate and format output
    validate_output
    
    # Cleanup
    rm -f "$TEMP_FILE"
    
    echo ""
    echo "Team members template has been generated successfully!"
    echo "You can now edit $OUTPUT_FILE to add team members to each team."
    echo ""
    echo "Next steps:"
    echo "1. Edit the generated file to add usernames to the members arrays"
    echo "2. Use this file as input for your Terraform team membership resources"
    echo "3. Apply your Terraform configuration to create the team memberships"
}

# Execute main function with all arguments
main "$@"