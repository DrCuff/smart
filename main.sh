#!/bin/bash
# Main RAID5 Health Monitor Script
# Sources all component scripts and orchestrates the analysis

# Source all component scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/smart_parse.sh"
source "$SCRIPT_DIR/print_statements.sh"

# Main execution
main() {
    # Initialize
    print_header "🔍 ADVANCED RAID5 HEALTH ANALYSIS SYSTEM"
    print_methodology_section
    
    # Get and parse SMART data
    local smart_data
    if command -v promiseutilpro >/dev/null 2>&1; then
        smart_data=$(promiseutilpro -C smart)
    else
        echo -e "${YELLOW}Warning: promiseutilpro not found, using demonstration mode${RESET}"
        smart_data="mock"
    fi
    
    # Parse SMART data into temp files
    parse_smart_data "$smart_data"
    
    # Individual drive analysis
    print_section "💿 Individual Drive Analysis"
    local drive_count=0
    local total_risk=0
    local max_risk=0
    
    # Process each drive
    while IFS=',' read -r pdid model health temp age_years realloc pending offline poh \
        raw_read_error seek_error spin_retry start_stop power_cycle \
        uncorr_error crc_error load_cycle gsense_error temp_min \
        total_written total_read; do
        
        [ -z "$pdid" ] && continue
        
        drive_count=$((drive_count + 1))
        
        # Calculate risk and store data
        local drive_tier=$(get_drive_tier "$model")
        local base_afr=$(get_tier_afr "$drive_tier")
        local risk_pct=$(calculate_risk_percentage "$base_afr" "$age_years" "$temp" "$realloc" "$pending" "$offline" "$poh" "$model" "$raw_read_error" "$seek_error" "$spin_retry" "$uncorr_error" "$crc_error")
        
        echo "$drive_tier,$risk_pct" >> /tmp/drive_tiers.tmp
        echo "$pdid,$temp,$raw_read_error,$seek_error,$start_stop,$power_cycle,$load_cycle,$total_written,$total_read" >> /tmp/smart_comparison.tmp
        
        # Display individual drive info
        print_individual_drive_info "$pdid" "$model" "$health" "$temp" "$age_years" "$temp_min" "$poh" \
            "$power_cycle" "$start_stop" "$load_cycle" "$total_written" "$total_read" \
            "$realloc" "$pending" "$offline" "$spin_retry" "$uncorr_error" "$crc_error" \
            "$raw_read_error" "$seek_error" "$risk_pct"
        
        # Track totals
        total_risk=$(awk -v t="$total_risk" -v r="$risk_pct" 'BEGIN {print t + r}')
        if awk -v r="$risk_pct" -v m="$max_risk" 'BEGIN {exit (r > m) ? 0 : 1}'; then
            max_risk="$risk_pct"
        fi
        
    done < /tmp/parsed_drives.tmp
    
    # SMART comparison section
    print_smart_comparisons
    
    # Health summary
    print_health_summary
    
    # Industry comparison
    print_industry_comparison
    
    # RAID5 array analysis
    if [ "$drive_count" -gt 0 ]; then
        local avg_risk=$(awk -v total="$total_risk" -v count="$drive_count" 'BEGIN {printf "%.1f", total/count}')
        print_array_analysis "$drive_count" "$avg_risk"
        print_workload_analysis
    fi
    
    # Footer
    print_footer
    
    # Cleanup
    rm -f /tmp/parsed_drives.tmp /tmp/drive_tiers.tmp /tmp/smart_comparison.tmp
}

# Run main function
main "$@"
