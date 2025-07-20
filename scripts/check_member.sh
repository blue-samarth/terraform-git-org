#!/bin/bash

# Script to validate team members against organization membership
# This script checks if all team members listed in team_members.tfvars.json
# are actually members of the organization as defined in members.json

set -e

# Configuration
TEAM_MEMBERS_FILE="team_members.tfvars.json"
ORG_MEMBERS_FILE="members.tfvars.json"
REPORT_FILE="validation_report.json"
TEMP_FILE=$(mktemp)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Error: The following required tools are missing: ${missing_tools[*]}${NC}"
        echo "Please install jq and try again."
        exit 1
    fi
}

# Function to validate input files
validate_input_files() {
    local files_missing=()
    
    # Check if team members file exists
    if [ ! -f "$TEAM_MEMBERS_FILE" ]; then
        files_missing+=("$TEAM_MEMBERS_FILE")
    fi
    
    # Check if organization members file exists
    if [ ! -f "$ORG_MEMBERS_FILE" ]; then
        files_missing+=("$ORG_MEMBERS_FILE")
    fi
    
    if [ ${#files_missing[@]} -ne 0 ]; then
        echo -e "${RED}Error: The following required files are missing:${NC}"
        printf '%s\n' "${files_missing[@]}"
        echo ""
        echo "Required files:"
        echo "- $TEAM_MEMBERS_FILE: Contains team membership definitions"
        echo "- $ORG_MEMBERS_FILE: Contains organization membership list"
        exit 1
    fi
    
    # Validate JSON structure of team members file
    if ! jq empty "$TEAM_MEMBERS_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Invalid JSON format in '$TEAM_MEMBERS_FILE'.${NC}"
        exit 1
    fi
    
    # Validate JSON structure of organization members file
    if ! jq empty "$ORG_MEMBERS_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Invalid JSON format in '$ORG_MEMBERS_FILE'.${NC}"
        exit 1
    fi
    
    # Check for required structure in organization members file
    if ! jq -e '.members' "$ORG_MEMBERS_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: 'members' key not found in '$ORG_MEMBERS_FILE'.${NC}"
        echo "Expected structure: {\"members\": [\"username1\", \"username2\", ...]}"
        exit 1
    fi
}

# Function to extract all team members from the team structure
extract_all_team_members() {
    local all_members
    all_members=$(jq -r '
        [
            .root_teams[]?.members[]?,
            .subteams[]?.members[]?
        ] | map(select(. != null and . != "")) | unique | .[]
    ' "$TEAM_MEMBERS_FILE" 2>/dev/null)
    
    echo "$all_members"
}
# Function to validate members against organization
validate_members() {
    echo -e "${BLUE}Validating team members against organization membership...${NC}"
    
    # Get organization members
    local org_members
    org_members=$(jq -r '.members[]' "$ORG_MEMBERS_FILE" | sort)
    
    # Get all team members
    local team_members
    team_members=$(extract_all_team_members | sort)
    
    if [ -z "$team_members" ]; then
        echo -e "${YELLOW}Warning: No team members found in team configuration.${NC}"
        return 0
    fi
    
    # Create arrays for validation results
    local valid_members=()
    local invalid_members=()
    local team_member_count=0
    
    # Validate each team member
    while IFS= read -r member; do
        if [ -n "$member" ]; then
            team_member_count=$((team_member_count + 1))
            if echo "$org_members" | grep -q "^$member$"; then
                valid_members+=("$member")
            else
                invalid_members+=("$member")
            fi
        fi
    done <<< "$team_members"
    
    # Generate detailed validation report
    generate_detailed_report "${valid_members[@]}" "${invalid_members[@]}"
    
    # Display summary
    echo ""
    echo -e "${BLUE}Validation Summary:${NC}"
    echo "==================="
    echo "Total unique team members: $team_member_count"
    echo -e "Valid members (in org): ${GREEN}${#valid_members[@]}${NC}"
    echo -e "Invalid members (not in org): ${RED}${#invalid_members[@]}${NC}"
    
    if [ ${#invalid_members[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Invalid members found:${NC}"
        printf '%s\n' "${invalid_members[@]}" | sed 's/^/  - /'
        return 1
    else
        echo ""
        echo -e "${GREEN}✓ All team members are valid organization members!${NC}"
        return 0
    fi
}

# Function to generate detailed validation report
generate_detailed_report() {
    local valid_members=("${@}")
    local invalid_members=()
    
    # Split arguments - everything after the first empty string are invalid members
    local found_separator=false
    local temp_valid=()
    
    for arg in "${@}"; do
        if [ "$arg" = "SEPARATOR" ]; then
            found_separator=true
            continue
        fi
        
        if [ "$found_separator" = true ]; then
            invalid_members+=("$arg")
        else
            temp_valid+=("$arg")
        fi
    done
    
    # If no separator found, need to recalculate
    if [ "$found_separator" = false ]; then
        # Recalculate invalid members
        local org_members_list
        org_members_list=$(jq -r '.members[]' "$ORG_MEMBERS_FILE")
        
        invalid_members=()
        local all_team_members
        all_team_members=$(extract_all_team_members)
        
        while IFS= read -r member; do
            if [ -n "$member" ]; then
                if ! echo "$org_members_list" | grep -q "^$member$"; then
                    invalid_members+=("$member")
                fi
            fi
        done <<< "$all_team_members"
    fi
    
    # Create detailed report with team-by-team breakdown
    jq -n \
        --argjson team_data "$(cat "$TEAM_MEMBERS_FILE")" \
        --argjson org_members "$(jq '.members' "$ORG_MEMBERS_FILE")" \
        --argjson invalid_members "$(printf '%s\n' "${invalid_members[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        '
        {
            "validation_timestamp": now | strftime("%Y-%m-%d %H:%M:%S UTC"),
            "organization_member_count": ($org_members | length),
            "validation_results": {
                "root_teams": ($team_data.root_teams | map({
                    "name": .name,
                    "member_count": (.members | length),
                    "members": (.members | map({
                        "username": .,
                        "valid": (. as $member | $invalid_members | index($member) | not)
                    })),
                    "invalid_members": (.members | map(select(. as $member | $invalid_members | index($member) != null)))
                })),
                "subteams": ($team_data.subteams | map({
                    "name": .name,
                    "parent_team": .parent_team,
                    "member_count": (.members | length),
                    "members": (.members | map({
                        "username": .,
                        "valid": (. as $member | $invalid_members | index($member) | not)
                    })),
                    "invalid_members": (.members | map(select(. as $member | $invalid_members | index($member) != null)))
                }))
            },
            "summary": {
                "total_unique_team_members": ([$team_data.root_teams[].members[], $team_data.subteams[].members[]] | unique | length),
                "valid_members": ([$team_data.root_teams[].members[], $team_data.subteams[].members[]] | unique | map(select(. as $member | $invalid_members | index($member) | not)) | length),
                "invalid_members": ($invalid_members | length),
                "teams_with_invalid_members": (
                    [$team_data.root_teams[], $team_data.subteams[]] | 
                    map(select(.members | map(select(. as $member | $invalid_members | index($member) != null)) | length > 0)) | 
                    length
                )
            },
            "invalid_members_list": $invalid_members
        }' > "$REPORT_FILE"
    
    echo ""
    echo -e "${BLUE}Detailed validation report saved to: $REPORT_FILE${NC}"
}

# Function to display team-by-team breakdown
show_team_breakdown() {
    echo ""
    echo -e "${BLUE}Team-by-Team Validation Breakdown:${NC}"
    echo "===================================="
    
    # Organization members for lookup
    local org_members
    org_members=$(jq -r '.members[]' "$ORG_MEMBERS_FILE")
    
    # Check root teams
    echo ""
    echo -e "${BLUE}Root Teams:${NC}"
    
    jq -r '.root_teams[] | "\(.name):\(.members)"' "$TEAM_MEMBERS_FILE" | while IFS=: read -r team_name members_json; do
        echo "  Team: $team_name"
        
        if [ "$members_json" = "[]" ]; then
            echo -e "    ${YELLOW}No members${NC}"
        else
            echo "$members_json" | jq -r '.[]' | while read -r member; do
                if echo "$org_members" | grep -q "^$member$"; then
                    echo -e "    ${GREEN}✓${NC} $member"
                else
                    echo -e "    ${RED}✗${NC} $member (not in org)"
                fi
            done
        fi
        echo ""
    done
    
    # Check subteams
    echo -e "${BLUE}Subteams:${NC}"
    
    jq -r '.subteams[] | "\(.name):\(.parent_team):\(.members)"' "$TEAM_MEMBERS_FILE" | while IFS=: read -r team_name parent_team members_json; do
        echo "  Subteam: $team_name (parent: $parent_team)"
        
        if [ "$members_json" = "[]" ]; then
            echo -e "    ${YELLOW}No members${NC}"
        else
            echo "$members_json" | jq -r '.[]' | while read -r member; do
                if echo "$org_members" | grep -q "^$member$"; then
                    echo -e "    ${GREEN}✓${NC} $member"
                else
                    echo -e "    ${RED}✗${NC} $member (not in org)"
                fi
            done
        fi
        echo ""
    done
}

# Function to display member-to-teams mapping
# Function to display member-to-teams mapping
show_member_teams_mapping() {
    echo ""
    echo -e "${BLUE}Member-to-Teams Mapping:${NC}"
    echo "========================="
    echo ""
    
    # Create associative array to track member->teams mapping
    declare -A member_to_teams
    
    # Get org members for validation
    local org_members
    org_members=$(jq -r '.members[]' "$ORG_MEMBERS_FILE" 2>/dev/null | sort)
    
    # Process root teams
    while read -r team_data; do
        if [ -n "$team_data" ] && [ "$team_data" != "null" ]; then
            local team_name=$(echo "$team_data" | cut -d':' -f1)
            local member=$(echo "$team_data" | cut -d':' -f2)
            
            if [ -n "$member" ] && [ "$member" != "null" ]; then
                if [ -n "${member_to_teams[$member]}" ]; then
                    member_to_teams[$member]="${member_to_teams[$member]},$team_name"
                else
                    member_to_teams[$member]="$team_name"
                fi
            fi
        fi
    done < <(jq -r '.root_teams[]? | select(.members != null and (.members | length) > 0) | .name as $team | .members[] | "\($team):\(.)"' "$TEAM_MEMBERS_FILE" 2>/dev/null)
    
    # Process subteams
    while read -r team_data; do
        if [ -n "$team_data" ] && [ "$team_data" != "null" ]; then
            local team_name=$(echo "$team_data" | cut -d':' -f1)
            local member=$(echo "$team_data" | cut -d':' -f2)
            
            if [ -n "$member" ] && [ "$member" != "null" ]; then
                if [ -n "${member_to_teams[$member]}" ]; then
                    member_to_teams[$member]="${member_to_teams[$member]},$team_name"
                else
                    member_to_teams[$member]="$team_name"
                fi
            fi
        fi
    done < <(jq -r '.subteams[]? | select(.members != null and (.members | length) > 0) | .name as $team | .members[] | "\($team):\(.)"' "$TEAM_MEMBERS_FILE" 2>/dev/null)
    
    # Display the mapping
    for member in $(printf '%s\n' "${!member_to_teams[@]}" | sort); do
        if echo "$org_members" | grep -q "^$member$"; then
            echo -e "${GREEN}$member${NC} : ${member_to_teams[$member]}"
        else
            echo -e "${RED}$member${NC} : ${member_to_teams[$member]} ${RED}(not in org)${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}Organization members not in any team:${NC}"
    
    # Find org members who are not in any team
    while read -r org_member; do
        if [ -n "$org_member" ] && [ -z "${member_to_teams[$org_member]}" ]; then
            echo -e "  ${YELLOW}$org_member${NC} : (no teams assigned)"
        fi
    done <<< "$org_members"
}


# Function to show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script validates that all team members listed in your team configuration
are actual members of the organization.

OPTIONS:
    -h, --help           Show this help message
    -t, --teams          Specify team members file (default: team_members.tfvars.json)
    -m, --members        Specify organization members file (default: members.json)
    -r, --report         Specify validation report output file (default: validation_report.json)
    -v, --verbose        Show detailed team-by-team breakdown
    -u, --users          Show member-to-teams mapping (username : TEAM A, TEAM B...)
    --no-color           Disable colored output

EXAMPLES:
    $0                                    # Validate with default files
    $0 -v                                 # Show verbose team breakdown
    $0 -u                                 # Show member-to-teams mapping
    $0 -v -u                              # Show both breakdowns
    $0 -t custom_teams.json               # Use custom team file
    $0 -m org_members.json                # Use custom org members file
    $0 --no-color                         # Disable colored output

INPUT FILES:
    Team Members File (team_members.tfvars.json):
    {
        "root_teams": [
            {
                "name": "Team A",
                "members": ["alice", "bob"]
            }
        ],
        "subteams": [
            {
                "name": "Subteam A1",
                "parent_team": "Team A",
                "members": ["charlie"]
            }
        ]
    }

    Organization Members File (members.json):
    {
        "members": ["alice", "bob", "charlie", "dave"]
    }

OUTPUT:
    - Console output with validation results
    - JSON report file with detailed validation data
    - Exit code 0 if all members are valid, 1 if invalid members found

EOF
}

# Main execution function
main() {
    local team_file="$TEAM_MEMBERS_FILE"
    local org_file="$ORG_MEMBERS_FILE"
    local report_file="$REPORT_FILE"
    local verbose=false
    local show_user_mapping=false
    local use_color=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -t|--teams)
                team_file="$2"
                shift 2
                ;;
            -m|--members)
                org_file="$2"
                shift 2
                ;;
            -r|--report)
                report_file="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -u|--users)
                show_user_mapping=true
                shift
                ;;
            --no-color)
                use_color=false
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Disable colors if requested
    if [ "$use_color" = false ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
    
    # Update global variables
    TEAM_MEMBERS_FILE="$team_file"
    ORG_MEMBERS_FILE="$org_file"
    REPORT_FILE="$report_file"
    
    echo -e "${BLUE}Team Members Validator${NC}"
    echo "====================="
    echo "Team members file: $TEAM_MEMBERS_FILE"
    echo "Organization members file: $ORG_MEMBERS_FILE"
    echo "Validation report: $REPORT_FILE"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Validate input files
    validate_input_files
    
    # Perform validation
    local validation_result=0
    validate_members || validation_result=$?
    
    # Show detailed breakdown if requested
    if [ "$verbose" = true ]; then
        show_team_breakdown
    fi
    
    # Show member-to-teams mapping if requested
    if [ "$show_user_mapping" = true ]; then
        show_member_teams_mapping
    fi
    
    # Cleanup
    rm -f "$TEMP_FILE"
    
    echo ""
    if [ $validation_result -eq 0 ]; then
        echo -e "${GREEN}✓ Validation completed successfully - all team members are valid!${NC}"
    else
        echo -e "${RED}✗ Validation failed - some team members are not organization members!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Review the invalid members listed above"
        echo "2. Either add them to the organization or remove them from teams"
        echo "3. Check the detailed report in $REPORT_FILE"
    fi
    
    exit $validation_result
}

# Execute main function with all arguments
main "$@"