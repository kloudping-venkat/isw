#!/bin/bash

# Helper script to format Terraform import commands for the pipeline
# This script helps convert terraform import commands into the format needed for the pipeline

echo "=== Terraform Import List Helper ==="
echo "This script helps you format terraform import commands for the pipeline"
echo ""

# Function to convert terraform import command to pipeline format
convert_import_command() {
    local import_command="$1"
    
    # Extract terraform address and azure resource id from: terraform import 'address' 'resource_id'
    if [[ $import_command =~ terraform[[:space:]]+import[[:space:]]+[\'\"]?([^\'\"[:space:]]+)[\'\"]?[[:space:]]+[\'\"]?([^\'\"]+)[\'\"]? ]]; then
        terraform_address="${BASH_REMATCH[1]}"
        azure_resource_id="${BASH_REMATCH[2]}"
        echo "${terraform_address}|${azure_resource_id}"
    else
        echo "ERROR: Could not parse import command: $import_command"
        return 1
    fi
}

# Check if input is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [import_commands_file] or provide commands interactively"
    echo ""
    echo "Example terraform import commands:"
    echo "  terraform import 'module.example.azurerm_subnet.main' '/subscriptions/.../subnets/subnet-name'"
    echo "  terraform import 'azurerm_resource_group.example' '/subscriptions/.../resourceGroups/rg-name'"
    echo ""
    echo "This will be converted to pipeline format:"
    echo "  module.example.azurerm_subnet.main|/subscriptions/.../subnets/subnet-name"
    echo ""
    
    # Interactive mode
    echo "Enter your terraform import commands (one per line, empty line to finish):"
    import_list=""
    while true; do
        read -r line
        if [ -z "$line" ]; then
            break
        fi
        
        converted=$(convert_import_command "$line")
        if [ $? -eq 0 ]; then
            if [ -z "$import_list" ]; then
                import_list="$converted"
            else
                import_list="$import_list,$converted"
            fi
        fi
    done
else
    # File mode
    import_file="$1"
    if [ ! -f "$import_file" ]; then
        echo "ERROR: File '$import_file' not found"
        exit 1
    fi
    
    echo "Processing import commands from: $import_file"
    import_list=""
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        converted=$(convert_import_command "$line")
        if [ $? -eq 0 ]; then
            if [ -z "$import_list" ]; then
                import_list="$converted"
            else
                import_list="$import_list,$converted"
            fi
        fi
    done < "$import_file"
fi

if [ -z "$import_list" ]; then
    echo "No valid import commands found."
    exit 1
fi

echo ""
echo "=== PIPELINE PARAMETER ==="
echo "Copy this value into the 'customImportList' parameter in your pipeline:"
echo ""
echo "$import_list"
echo ""
echo "=== USAGE INSTRUCTIONS ==="
echo "1. Copy the above line"
echo "2. Run your Azure DevOps pipeline"
echo "3. Paste it into the 'Custom Import List' parameter"
echo "4. Set action to 'plan-and-apply'"
echo "5. Leave 'importResources' as false (unless you want both)"
echo ""
echo "The pipeline will import each resource before running terraform apply."