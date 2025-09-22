#!/bin/bash
# All print and display functions for RAID5 health monitoring

print_header() {
    local title="$1"
    local width=${2:-$TERMINAL_WIDTH}
    local padding=$(( (width - ${#title} - 4) / 2 ))
    
    echo -e "${BOLD}${CYAN}"
    printf "╔"
    for i in $(seq 1 $((width-2))); do printf "═"; done
    printf "╗\n"
    
    printf "║"
    for i in $(seq 1 $padding); do printf " "; done
    printf "%s" "$title"
    for i in $(seq 1 $((width - padding - ${#title} - 3))); do printf " "; done
    printf "║\n"
    
    printf "╚"
    for i in $(seq 1 $((width-2))); do printf "═"; done
    printf "╝${RESET}\n"
}

print_section() {
    local title="$1"
    echo -e "\n${BOLD}${WHITE}▶ $title${RESET}"
    local line=""
    for i in $(seq 1 ${#title}); do line="${line}─"; done
    echo -e "${DIM}${line}${RESET}"
}

print_methodology_section() {
    print_section "📋 Risk Assessment Methodology"
    echo -e "${DIM}Statistical model based on peer-reviewed research (Google, Backblaze studies)${RESET}"
    echo -e "${DIM}• Bathtub curve aging model with infant mortality and wear-out phases${RESET}"
    echo -e "${DIM}• Weighted SMART attributes using predictive failure indicators${RESET}"
    echo -e "${DIM}• Manufacturer-specific Annual Failure Rate (AFR) baselines${RESET}"
    echo -e "${DIM}• Non-linear risk scaling for critical sector reallocation${RESET}"
}

print_individual_drive_info() {
    local pdid="$1" model="$2" health="$3" temp="$4" age_years="$5" temp_min="$6" poh="$7"
    local power_cycle="$8" start_stop="$9" load_cycle="${10}" total_written="${11}" total_read="${12}"
    local realloc="${13}" pending="${14}" offline="${15}" spin_retry="${16}" uncorr_error="${17}" crc_error="${18}"
    local raw_read_error="${19}" seek_error="${20}" risk_pct="${21}"
    
    echo -e "\n${BOLD}${BLUE}Drive $pdid${RESET} ${DIM}($model)${RESET}"
    
    # Health indicator
    local health_icon="$OK" health_color="$GREEN"
    if awk -v r="$risk_pct" 'BEGIN {exit (r >= 15) ? 0 : 1}'; then
        health_icon="$DANGER"; health_color="$RED"
    elif awk -v r="$risk_pct" 'BEGIN {exit (r >= 5) ? 0 : 1}'; then
        health_icon="$WARNING"; health_color="$YELLOW"
    fi
    
    echo -e "  Status: ${health_color}$health $health_icon${RESET}"
    
    local poh_years=$(awk -v p="$poh" 'BEGIN {printf "%.1f", p/8760}')
    echo -e "  Temperature: ${temp}°C (Min: ${temp_min}°C) | Age: $(printf "%.1f" "$age_years") years | Runtime: ${poh_years} years"
    echo -e "  Power Cycles: $(format_number "$power_cycle") | Start/Stop: $(format_number "$start_stop") | Load Cycles: $(format_number "$load_cycle")"
    echo -e "  Data Written: ${total_written}GB | Data Read: ${total_read}GB"
    
    # Show critical SMART issues
    [ "$realloc" -gt 0 ] && echo -e "  ${RED}⚠ Reallocated Sectors: $realloc${RESET}"
    [ "$pending" -gt 0 ] && echo -e "  ${RED}⚠ Pending Sectors: $pending${RESET}"
    [ "$offline" -gt 0 ] && echo -e "  ${RED}⚠ Offline Uncorrectable: $offline${RESET}"
    [ "$spin_retry" -gt 0 ] && echo -e "  ${RED}⚠ Spin Retry Count: $spin_retry${RESET}"
    [ "$uncorr_error" -gt 0 ] && echo -e "  ${RED}⚠ Uncorrectable Errors: $uncorr_error${RESET}"
    [ "$crc_error" -gt 0 ] && echo -e "  ${YELLOW}⚠ CRC Errors: $crc_error${RESET}"
    
    # Show error rates if significant
    if [ "$poh" -gt 1000 ]; then
        local read_error_rate=$(awk -v err="$raw_read_error" -v hours="$poh" 'BEGIN {printf "%.0f", err/hours}')
        local seek_error_rate=$(awk -v err="$seek_error" -v hours="$poh" 'BEGIN {printf "%.0f", err/hours}')
        
        [ "$read_error_rate" -gt 1000 ] && echo -e "  ${YELLOW}📊 High Read Error Rate: $(format_number "$read_error_rate")/hour${RESET}"
        [ "$seek_error_rate" -gt 1000 ] && echo -e "  ${YELLOW}📊 High Seek Error Rate: $(format_number "$seek_error_rate")/hour${RESET}"
    fi
    
    # Drive tier info
    local drive_tier=$(get_drive_tier "$model")
    local tier_name=$(get_tier_display_name "$drive_tier")
    local tier_color=$(get_tier_color "$drive_tier")
    echo -e "  ${DIM}Drive Tier: ${tier_color}$tier_name${RESET}${DIM} - $(get_tier_description "$drive_tier")${RESET}"
    
    # Risk visualization
    local risk_bar=$(make_risk_bar "$risk_pct" "$BAR_WIDTH")
    echo -e "  Failure Risk: [$risk_bar] ${BOLD}${risk_pct}%${RESET} annually"
    
    # Recommendations
    if awk -v r="$risk_pct" 'BEGIN {exit (r > 15) ? 0 : 1}'; then
        echo -e "  ${RED}⚠  URGENT: Replace within 3 months${RESET}"
    elif awk -v r="$risk_pct" 'BEGIN {exit (r > 8) ? 0 : 1}'; then
        echo -e "  ${YELLOW}⏰ Plan replacement within 6-12 months${RESET}"
    elif awk -v r="$risk_pct" 'BEGIN {exit (r > 3) ? 0 : 1}'; then
        echo -e "  ${YELLOW}📋 Consider replacement in next refresh cycle${RESET}"
    else
        echo -e "  ${GREEN}✓ Healthy - Continue monitoring${RESET}"
    fi
}

print_smart_comparisons() {
    print_section "📊 SMART Attribute Comparison Across Drives"
    
    echo -e "\n${BOLD}${WHITE}Temperature Comparison:${RESET}"
    echo -e "${DIM}Current operating temperatures across all drives${RESET}\n"
    
    local max_temp=$(awk -F',' 'BEGIN{max=0} {if($2>max) max=$2} END{print max}' /tmp/smart_comparison.tmp)
    local max_raw_read=$(awk -F',' 'BEGIN{max=0} {if($3>max) max=$3} END{print max}' /tmp/smart_comparison.tmp)
    local max_seek_error=$(awk -F',' 'BEGIN{max=0} {if($4>max) max=$4} END{print max}' /tmp/smart_comparison.tmp)
    local max_power_cycle=$(awk -F',' 'BEGIN{max=0} {if($6>max) max=$6} END{print max}' /tmp/smart_comparison.tmp)
    local max_load_cycle=$(awk -F',' 'BEGIN{max=0} {if($7>max) max=$7} END{print max}' /tmp/smart_comparison.tmp)
    local max_written=$(awk -F',' 'BEGIN{max=0} {if($8>max) max=$8} END{print max}' /tmp/smart_comparison.tmp)
    local max_read=$(awk -F',' 'BEGIN{max=0} {if($9>max) max=$9} END{print max}' /tmp/smart_comparison.tmp)

    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local temp_bar=$(make_comparison_bar "$temp" "$max_temp" 30 "true")
        printf "  Drive %-2s: [%s] %2d°C\n" "$pdid" "$temp_bar" "$temp"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${BOLD}${WHITE}Read Error Rate Comparison:${RESET}"
    echo -e "${DIM}Raw read error counts (lower is better)${RESET}\n"

    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local read_bar=$(make_comparison_bar "$raw_read" "$max_raw_read" 30 "true")
        printf "  Drive %-2s: [%s] %s errors\n" "$pdid" "$read_bar" "$(format_number "$raw_read")"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${BOLD}${WHITE}Seek Error Rate Comparison:${RESET}"
    echo -e "${DIM}Seek error counts (lower is better)${RESET}\n"

    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local seek_bar=$(make_comparison_bar "$seek_error" "$max_seek_error" 30 "true")
        printf "  Drive %-2s: [%s] %s errors\n" "$pdid" "$seek_bar" "$(format_number "$seek_error")"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${BOLD}${WHITE}Power Cycle Comparison:${RESET}"
    echo -e "${DIM}Total power on/off cycles (age-related wear indicator)${RESET}\n"

    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local cycle_bar=$(make_comparison_bar "$power_cycle" "$max_power_cycle" 30 "false")
        printf "  Drive %-2s: [%s] %s cycles\n" "$pdid" "$cycle_bar" "$(format_number "$power_cycle")"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${BOLD}${WHITE}Load Cycle Comparison:${RESET}"
    echo -e "${DIM}Head load/unload cycles (mechanical wear indicator)${RESET}\n"

    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local load_bar=$(make_comparison_bar "$load_cycle" "$max_load_cycle" 30 "false")
        printf "  Drive %-2s: [%s] %s cycles\n" "$pdid" "$load_bar" "$(format_number "$load_cycle")"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${BOLD}${WHITE}Data Usage Comparison:${RESET}"
    echo -e "${DIM}Total data written and read (workload indicators)${RESET}\n"

    echo -e "${CYAN}Data Written:${RESET}"
    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local written_bar=$(make_comparison_bar "$(awk -v w="$total_written" 'BEGIN {print int(w)}')" "$(awk -v m="$max_written" 'BEGIN {print int(m)}')" 30 "false")
        printf "  Drive %-2s: [%s] %.1f GB\n" "$pdid" "$written_bar" "$total_written"
    done < /tmp/smart_comparison.tmp

    echo -e "\n${CYAN}Data Read:${RESET}"
    while IFS=',' read -r pdid temp raw_read seek_error start_stop power_cycle load_cycle total_written total_read; do
        local read_bar=$(make_comparison_bar "$(awk -v r="$total_read" 'BEGIN {print int(r)}')" "$(awk -v m="$max_read" 'BEGIN {print int(m)}')" 30 "false")
        printf "  Drive %-2s: [%s] %.1f GB\n" "$pdid" "$read_bar" "$total_read"
    done < /tmp/smart_comparison.tmp
}

print_health_summary() {
    print_section "🏥 SMART Health Summary"
    
    echo -e "\n${BOLD}${WHITE}Critical Issues Detected:${RESET}"
    local critical_found=false
    
    while IFS=',' read -r pdid model health temp age_years realloc pending offline poh \
        raw_read_error seek_error spin_retry start_stop power_cycle \
        uncorr_error crc_error load_cycle gsense_error temp_min \
        total_written total_read; do
        
        if [ "$realloc" -gt 0 ] || [ "$pending" -gt 0 ] || [ "$offline" -gt 0 ] || [ "$spin_retry" -gt 0 ] || [ "$uncorr_error" -gt 0 ]; then
            critical_found=true
            echo -e "  ${RED}Drive $pdid:${RESET}"
            [ "$realloc" -gt 0 ] && echo -e "    • Reallocated Sectors: $realloc"
            [ "$pending" -gt 0 ] && echo -e "    • Pending Sectors: $pending"
            [ "$offline" -gt 0 ] && echo -e "    • Offline Uncorrectable: $offline"
            [ "$spin_retry" -gt 0 ] && echo -e "    • Spin Retry Count: $spin_retry"
            [ "$uncorr_error" -gt 0 ] && echo -e "    • Uncorrectable Errors: $uncorr_error"
        fi
    done < /tmp/parsed_drives.tmp
    
    if [ "$critical_found" = false ]; then
        echo -e "  ${GREEN}✓ No critical SMART issues detected across all drives${RESET}"
    fi

    echo -e "\n${BOLD}${WHITE}Performance Anomalies:${RESET}"
    local anomaly_found=false

    # Check for performance anomalies
    while IFS=',' read -r pdid model health temp age_years realloc pending offline poh \
        raw_read_error seek_error spin_retry start_stop power_cycle \
        uncorr_error crc_error load_cycle gsense_error temp_min \
        total_written total_read; do
        
        # Check for high error rates
        if [ "$poh" -gt 1000 ]; then
            local read_error_rate=$(awk -v err="$raw_read_error" -v hours="$poh" 'BEGIN {printf "%.0f", err/hours}')
            local seek_error_rate=$(awk -v err="$seek_error" -v hours="$poh" 'BEGIN {printf "%.0f", err/hours}')
            
            if [ "$read_error_rate" -gt 1000 ] || [ "$seek_error_rate" -gt 1000 ] || [ "$temp" -gt 40 ] || [ "$crc_error" -gt 0 ]; then
                anomaly_found=true
                echo -e "  ${YELLOW}Drive $pdid:${RESET}"
                [ "$read_error_rate" -gt 1000 ] && echo -e "    • High read error rate: $(format_number "$read_error_rate")/hour"
                [ "$seek_error_rate" -gt 1000 ] && echo -e "    • High seek error rate: $(format_number "$seek_error_rate")/hour"
                [ "$temp" -gt 40 ] && echo -e "    • High temperature: ${temp}°C"
                [ "$crc_error" -gt 0 ] && echo -e "    • CRC errors detected: $crc_error"
            fi
        fi
    done < /tmp/parsed_drives.tmp

    if [ "$anomaly_found" = false ]; then
        echo -e "  ${GREEN}✓ No significant performance anomalies detected${RESET}"
    fi
}

print_industry_comparison() {
    print_section "📊 Drive Performance vs Industry Standards"
    
    local enterprise_risk=$(calculate_risk_percentage "0.006" "4.0" "35" "0" "0" "0" "35040" "ENTERPRISE" "0" "0" "0" "0" "0")
    local nas_ent_risk=$(calculate_risk_percentage "0.008" "4.0" "35" "0" "0" "0" "35040" "VN008" "0" "0" "0" "0" "0")  
    local nas_con_risk=$(calculate_risk_percentage "0.012" "4.0" "35" "0" "0" "0" "35040" "RED" "0" "0" "0" "0" "0")
    local desktop_risk=$(calculate_risk_percentage "0.018" "4.0" "35" "0" "0" "0" "35040" "DM000" "0" "0" "0" "0" "0")

    echo -e "\n${BOLD}${WHITE}4-Year-Old Drive Comparison:${RESET}"
    echo -e "${DIM}How would different drive tiers perform at 4 years of 24/7 operation?${RESET}"
    echo -e "${DIM}(Scale: 0-5% risk for better comparison visibility)${RESET}\n"

    printf "  ${GREEN}%-25s${RESET}" "Enterprise Server:"
    printf "[%s] ${BOLD}%4.1f%%${RESET} - Premium reliability\n" "$(make_risk_bar "$enterprise_risk" "$BAR_WIDTH" "5")" "$enterprise_risk"

    printf "  ${GREEN}%-25s${RESET}" "Enterprise NAS:"
    printf "[%s] ${BOLD}%4.1f%%${RESET} - Your VN008 class\n" "$(make_risk_bar "$nas_ent_risk" "$BAR_WIDTH" "5")" "$nas_ent_risk"

    printf "  ${YELLOW}%-25s${RESET}" "Consumer NAS:"
    printf "[%s] ${BOLD}%4.1f%%${RESET} - Budget NAS drives\n" "$(make_risk_bar "$nas_con_risk" "$BAR_WIDTH" "5")" "$nas_con_risk"

    printf "  ${RED}%-25s${RESET}" "Desktop/Consumer:"
    printf "[%s] ${BOLD}%4.1f%%${RESET} - Your DM000 class\n" "$(make_risk_bar "$desktop_risk" "$BAR_WIDTH" "5")" "$desktop_risk"

    echo -e "\n${BOLD}${WHITE}Your Current Drives vs Standards:${RESET}"
    echo -e "${DIM}How your drives are performing compared to their tier expectations:${RESET}\n"
    
    awk -F',' '{tiers[$1] += $2; counts[$1]++} END {for (tier in tiers) printf "%s,%.1f,%d\n", tier, tiers[tier]/counts[tier], counts[tier]}' /tmp/drive_tiers.tmp | \
    while IFS=',' read -r tier avg_risk drive_count_tier; do
        local tier_name=$(get_tier_display_name "$tier")
        local tier_color=$(get_tier_color "$tier")
        local tier_label="${tier_name}s (${drive_count_tier})"
        
        printf "  ${tier_color}%-25s${RESET}" "$tier_label:"
        printf "[%s] ${BOLD}%4.1f%%${RESET}" "$(make_risk_bar "$avg_risk" "$BAR_WIDTH" "5")" "$avg_risk"
        
        case "$tier" in
            "enterprise"|"enterprise_nas") local standard_risk="$nas_ent_risk";;
            "consumer_nas") local standard_risk="$nas_con_risk";;
            "desktop") local standard_risk="$desktop_risk";;
            *) local standard_risk="$nas_con_risk";;
        esac
        
        if awk -v actual="$avg_risk" -v standard="$standard_risk" 'BEGIN {exit (actual <= standard * 0.8) ? 0 : 1}'; then
            echo -e " ${GREEN}✓ Excellent${RESET} (Better than expected)"
        elif awk -v actual="$avg_risk" -v standard="$standard_risk" 'BEGIN {exit (actual <= standard * 1.2) ? 0 : 1}'; then
            echo -e " ${YELLOW}~ Normal${RESET} (Within expected range)"
        else
            echo -e " ${RED}⚠ Above Average${RESET} (Consider monitoring closely)"
        fi
    done
}

print_array_analysis() {
    local drive_count="$1"
    local avg_risk="$2"
    
    print_section "🏗️ RAID5 Array Risk Analysis"
    
    local array_failure_pct=$(calculate_array_failure_prob "$drive_count" "$avg_risk")
    
    echo -e "\n${BOLD}${WHITE}Array Configuration:${RESET}"
    echo -e "  • Total Drives: $drive_count"
    echo -e "  • Redundancy: Single drive fault tolerance (RAID5)"
    echo -e "  • Critical Threshold: ${RED}2 simultaneous failures = DATA LOSS${RESET}"
    
    echo -e "\n${BOLD}${WHITE}Risk Assessment (12-month horizon):${RESET}"
    echo -e "  • Average Drive Risk: ${avg_risk}%"
    echo -e "  • Array Failure Probability: ${BOLD}$array_failure_pct%${RESET}"
    
    # Risk level determination
    local risk_level="LOW" risk_color="$GREEN" risk_icon="$OK"
    
    if awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 5) ? 0 : 1}'; then
        risk_level="CRITICAL"; risk_color="$RED"; risk_icon="$DANGER"
    elif awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 1) ? 0 : 1}'; then
        risk_level="HIGH"; risk_color="$YELLOW"; risk_icon="$WARNING"
    elif awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 0.5) ? 0 : 1}'; then
        risk_level="MODERATE"; risk_color="$YELLOW"; risk_icon="$WARNING"
    fi
    
    echo -e "  • Risk Level: ${risk_color}${BOLD}$risk_level $risk_icon${RESET}"

    # Mixed array specific analysis
    local nas_count=$(awk -F',' '$2 ~ /VN008/ {count++} END {print count+0}' /tmp/parsed_drives.tmp)
    local desktop_count=$(awk -F',' '$2 ~ /DM000/ {count++} END {print count+0}' /tmp/parsed_drives.tmp)
    
    if [ "$nas_count" -gt 0 ] && [ "$desktop_count" -gt 0 ]; then
        echo -e "\n${BOLD}${WHITE}Mixed Array Analysis:${RESET}"
        echo -e "  • NAS drives (VN008): $nas_count units - ${GREEN}Lower risk baseline${RESET}"
        echo -e "  • Desktop drives (DM000): $desktop_count units - ${YELLOW}Monitor for age-related wear${RESET}"
        
        # Check for age stratification
        local old_drives=$(awk -F',' '$5 > 4 {count++} END {print count+0}' /tmp/parsed_drives.tmp)
        if [ "$old_drives" -gt 0 ]; then
            echo -e "  • ${RED}⚠ $old_drives drives over 4 years old - entering wear-out phase${RESET}"
        fi
        
        local aging_drives=$(awk -F',' '$5 > 3.5 && $5 <= 4 {count++} END {print count+0}' /tmp/parsed_drives.tmp)
        if [ "$aging_drives" -gt 0 ]; then
            echo -e "  • ${YELLOW}📋 $aging_drives drives approaching 4-year mark${RESET}"
        fi
    fi
    
    # Recommendations
    print_section "💡 Recommendations"
    
    if awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 5) ? 0 : 1}'; then
        echo -e "${RED}${BOLD}🚨 IMMEDIATE ACTION REQUIRED:${RESET}"
        echo -e "  • Replace highest-risk drives immediately"
        echo -e "  • Verify backup integrity and recency"
        echo -e "  • Consider temporary additional redundancy"
    elif awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 1) ? 0 : 1}'; then
        echo -e "${YELLOW}${BOLD}⚠️  PROACTIVE MAINTENANCE NEEDED:${RESET}"
        echo -e "  • Schedule drive replacements for high-risk drives"
        echo -e "  • Increase backup frequency"
        echo -e "  • Monitor SMART attributes weekly"
    elif awk -v pct="$array_failure_pct" 'BEGIN {exit (pct > 0.5) ? 0 : 1}'; then
        echo -e "${YELLOW}${BOLD}📋 MAINTENANCE PLANNING:${RESET}"
        echo -e "  • Plan proactive drive replacement for aging units"
        echo -e "  • Consider upgrading desktop drives to NAS-rated drives"
        echo -e "  • Maintain monthly monitoring schedule"
    else
        echo -e "${GREEN}${BOLD}✅ ARRAY IS HEALTHY:${RESET}"
        echo -e "  • Continue monthly SMART monitoring"
        echo -e "  • Maintain regular backup schedule"
        if [ "$desktop_count" -gt 0 ]; then
            echo -e "  • ${DIM}Consider NAS drives for next refresh cycle${RESET}"
        fi
        echo -e "  • Plan for drive refresh in 2-3 years"
    fi
    
    # Mixed array specific recommendations
    if [ "$nas_count" -gt 0 ] && [ "$desktop_count" -gt 0 ]; then
        echo -e "\n${BOLD}${CYAN}Mixed Array Optimization:${RESET}"
        echo -e "  • ${GREEN}Advantage:${RESET} NAS drives provide stability baseline"
        echo -e "  • ${YELLOW}Watch Point:${RESET} Desktop drives may age faster - stagger replacements"
        echo -e "  • ${BLUE}Future:${RESET} Consider standardizing on NAS-rated drives for 24/7 operation"
    fi
    
    # Environmental check
    local highest_temp=$(awk -F',' 'BEGIN{max=0} {if($4>max) max=$4} END{print max}' /tmp/parsed_drives.tmp)
    if [ "$highest_temp" -gt 45 ]; then
        echo -e "\n${YELLOW}🌡️  Temperature Alert: Highest drive temp is ${highest_temp}°C${RESET}"
        echo -e "   Consider improving case ventilation"
    fi
}

print_workload_analysis() {
    print_section "💾 Workload Analysis"
    
    local total_written_sum=$(awk -F',' '{sum += $20} END {printf "%.1f", sum}' /tmp/parsed_drives.tmp)
    local total_read_sum=$(awk -F',' '{sum += $21} END {printf "%.1f", sum}' /tmp/parsed_drives.tmp)
    local avg_written=$(awk -v sum="$total_written_sum" -v count="$drive_count" 'BEGIN {printf "%.1f", sum/count}')
    local avg_read=$(awk -v sum="$total_read_sum" -v count="$drive_count" 'BEGIN {printf "%.1f", sum/count}')
    
    echo -e "\n${BOLD}${WHITE}Array Workload Summary:${RESET}"
    echo -e "  • Total Data Written: ${total_written_sum} GB across all drives"
    echo -e "  • Total Data Read: ${total_read_sum} GB across all drives"  
    echo -e "  • Average per Drive: ${avg_written} GB written, ${avg_read} GB read"
    
    # Read/Write ratio analysis
    local rw_ratio=$(awk -v read="$total_read_sum" -v written="$total_written_sum" 'BEGIN {
        if (written > 0) printf "%.1f", read/written; else print "N/A"
    }')
    
    echo -e "  • Read/Write Ratio: ${rw_ratio}:1"
    
    if awk -v ratio="$rw_ratio" 'BEGIN {exit (ratio > 5) ? 0 : 1}' 2>/dev/null; then
        echo -e "  ${GREEN}📖 Read-heavy workload - drives optimized for this pattern${RESET}"
    elif awk -v ratio="$rw_ratio" 'BEGIN {exit (ratio < 2) ? 0 : 1}' 2>/dev/null; then
        echo -e "  ${YELLOW}✍️  Write-heavy workload - monitor for increased wear${RESET}"
    else
        echo -e "  ${BLUE}⚖️  Balanced read/write workload${RESET}"
    fi
}

print_footer() {
    echo -e "\n${DIM}─────────────────────────────────────────────────────────────${RESET}"
    echo -e "${DIM}Report generated: $(date)${RESET}"
    echo -e "${DIM}Next check recommended: $(date -v+1m 2>/dev/null || date -d '+1 month' 2>/dev/null || echo "1 month from now")${RESET}"
    echo -e "${DIM}Enhanced SMART analysis includes: Temperature, Error Rates, Power Cycles,${RESET}"
}
