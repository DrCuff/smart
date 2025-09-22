#!/bin/bash
# Core functions and calculations for RAID5 health monitoring

# Color and styling codes
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
WHITE="\033[1;37m"
DIM="\033[2m"
BOLD="\033[1m"
RESET="\033[0m"

# Unicode symbols
DANGER="🔴"
WARNING="🟡"
OK="🟢"
INFO="ℹ️"
CHART="📊"
TIME="⏰"

# Configuration
BAR_WIDTH=40
TERMINAL_WIDTH=80

# Drive tier classification
get_drive_tier() {
    local model="$1"
    local upper_model=$(echo "$model" | tr '[:lower:]' '[:upper:]')
    
    if echo "$upper_model" | grep -qE "VN008|WD4003FFBX|ST4000NE001|WD4002FYYZ|EXOS|IW-"; then
        echo "enterprise_nas"
    elif echo "$upper_model" | grep -qE "VN0|WD40EFRX|ST4000VN|RED|IHM|PLUS"; then
        echo "consumer_nas"
    elif echo "$upper_model" | grep -qE "DM000|WD40EZRZ|ST4000DM|BLUE|GREEN|BARRACUDA"; then
        echo "desktop"
    elif echo "$upper_model" | grep -qE "ENTERPRISE|RE4|SE16|ULTRASTAR|CONSTELLATION|CHEETAH"; then
        echo "enterprise"
    else
        echo "unknown"
    fi
}

get_tier_afr() {
    local tier="$1"
    case "$tier" in
        "enterprise") echo "0.006";;
        "enterprise_nas") echo "0.008";;
        "consumer_nas") echo "0.012";;
        "desktop") echo "0.018";;
        *) echo "0.015";;
    esac
}

get_tier_display_name() {
    local tier="$1"
    case "$tier" in
        "enterprise") echo "Enterprise Server";;
        "enterprise_nas") echo "Enterprise NAS";;
        "consumer_nas") echo "Consumer NAS";;
        "desktop") echo "Desktop/Consumer";;
        *) echo "Unknown Type";;
    esac
}

get_tier_description() {
    local tier="$1"
    case "$tier" in
        "enterprise") echo "24/7 server operation, 5-year warranty";;
        "enterprise_nas") echo "24/7 NAS operation, enterprise features";;
        "consumer_nas") echo "24/7 home/SMB NAS, optimized for RAID";;
        "desktop") echo "8hr/day desktop use, higher wear in 24/7";;
        *) echo "classification unknown";;
    esac
}

get_tier_color() {
    local tier="$1"
    case "$tier" in
        "enterprise") echo "$GREEN";;
        "enterprise_nas") echo "$GREEN";;
        "consumer_nas") echo "$YELLOW";;
        "desktop") echo "$RED";;
        *) echo "$WHITE";;
    esac
}

# Enhanced risk calculation with bathtub curve
calculate_risk_percentage() {
    local base_afr="$1"
    local age_years="$2"
    local temp="$3"
    local realloc="$4"
    local pending="$5"
    local offline="$6"
    local poh="$7"
    local model="$8"
    local raw_read_error="$9"
    local seek_error="${10}"
    local spin_retry="${11}"
    local uncorr_error="${12}"
    local crc_error="${13}"
    
    awk -v base="$base_afr" -v age="$age_years" -v temp="$temp" \
        -v realloc="$realloc" -v pending="$pending" -v offline="$offline" \
        -v poh="$poh" -v model="$model" -v raw_read="$raw_read_error" \
        -v seek_err="$seek_error" -v spin_retry="$spin_retry" \
        -v uncorr="$uncorr_error" -v crc="$crc_error" '
    BEGIN {
        risk = base
        age_factor = 0
        
        if (age < 0.5) {
            age_factor = 0.008 * (0.5 - age) * 2
        } else if (age >= 1 && age <= 5) {
            age_diff = age - 3
            if (age_diff < 0) age_diff = -age_diff
            age_factor = -0.002 * (3 - age_diff)
        } else if (age > 5) {
            excess = age - 5
            if (index(model, "DM000") > 0) {
                age_factor = excess * excess * 0.008
            } else {
                age_factor = excess * excess * 0.004
            }
        }
        
        poh_years = poh / 8760
        if (poh_years > 3) {
            poh_factor = (poh_years - 3) * 0.003
        } else {
            poh_factor = 0
        }
        
        smart_penalty = 0
        if (realloc > 0) smart_penalty += log(realloc + 1) * 0.02
        if (pending > 0) smart_penalty += log(pending + 1) * 0.025  
        if (offline > 0) smart_penalty += log(offline + 1) * 0.03
        if (spin_retry > 0) smart_penalty += log(spin_retry + 1) * 0.035
        if (uncorr > 0) smart_penalty += log(uncorr + 1) * 0.028
        if (crc > 0) smart_penalty += log(crc + 1) * 0.015
        
        if (raw_read > 1000000 && poh > 1000) {
            read_rate = raw_read / poh
            if (read_rate > 1000) smart_penalty += 0.005
        }
        
        if (seek_err > 1000000 && poh > 1000) {
            seek_rate = seek_err / poh
            if (seek_rate > 1000) smart_penalty += 0.008
        }
        
        temp_factor = 0
        if (temp > 40) {
            temp_excess = temp - 40
            temp_factor = temp_excess * temp_excess * 0.0008
        }
        
        total_risk = risk + age_factor + poh_factor + smart_penalty + temp_factor
        
        if (total_risk > 0.5) total_risk = 0.5
        if (total_risk < 0.005) total_risk = 0.005
        
        printf "%.1f", total_risk * 100
    }'
}

# Risk visualization bar
make_risk_bar() {
    local percentage="$1"
    local width="$2"
    local max_scale="${3:-25}"
    
    local filled=$(awk -v pct="$percentage" -v w="$width" -v scale="$max_scale" 'BEGIN {
        ratio = pct / scale
        if (ratio > 1) ratio = 1
        print int(ratio * w + 0.5)
    }')
    
    local bar=""
    local color=""
    
    if awk -v p="$percentage" 'BEGIN {exit (p >= 15) ? 0 : 1}'; then
        color="$RED"
    elif awk -v p="$percentage" 'BEGIN {exit (p >= 5) ? 0 : 1}'; then
        color="$YELLOW"  
    else
        color="$GREEN"
    fi
    
    for ((i=0; i<filled; i++)); do
        if [ $((i * 100 / width)) -lt 33 ]; then
            bar="${bar}█"
        elif [ $((i * 100 / width)) -lt 66 ]; then
            bar="${bar}▓"
        else
            bar="${bar}▒"
        fi
    done
    
    for ((i=filled; i<width; i++)); do
        bar="${bar}░"
    done
    
    echo -e "${color}${bar}${RESET}"
}

# SMART attribute comparison bar
make_comparison_bar() {
    local value="$1"
    local max_value="$2"
    local width="${3:-30}"
    local reverse_scale="${4:-false}"
    
    local percentage=0
    if [ "$max_value" -gt 0 ]; then
        percentage=$(awk -v val="$value" -v max="$max_value" 'BEGIN {
            pct = (val / max) * 100
            if (pct > 100) pct = 100
            printf "%.0f", pct
        }')
    fi
    
    local filled=$(awk -v pct="$percentage" -v w="$width" 'BEGIN {
        print int(pct * w / 100 + 0.5)
    }')
    
    local bar=""
    local color=""
    
    if [ "$reverse_scale" = "true" ]; then
        if [ "$percentage" -ge 80 ]; then
            color="$RED"
        elif [ "$percentage" -ge 50 ]; then
            color="$YELLOW"
        else
            color="$GREEN"
        fi
    else
        if [ "$percentage" -le 20 ]; then
            color="$RED"
        elif [ "$percentage" -le 60 ]; then
            color="$YELLOW"
        else
            color="$GREEN"
        fi
    fi
    
    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done
    
    for ((i=filled; i<width; i++)); do
        bar="${bar}░"
    done
    
    echo -e "${color}${bar}${RESET}"
}

# Format large numbers with units
format_number() {
    local num="$1"
    
    if [ "$num" -ge 1000000000 ]; then
        awk -v n="$num" 'BEGIN {printf "%.1fG", n/1000000000}'
    elif [ "$num" -ge 1000000 ]; then
        awk -v n="$num" 'BEGIN {printf "%.1fM", n/1000000}'
    elif [ "$num" -ge 1000 ]; then
        awk -v n="$num" 'BEGIN {printf "%.1fK", n/1000}'
    else
        echo "$num"
    fi
}

# RAID5 array failure probability calculation
calculate_array_failure_prob() {
    local drive_count="$1"
    local avg_risk_pct="$2"
    
    awk -v n="$drive_count" -v avg_pct="$avg_risk_pct" '
    BEGIN {
        p_fail = avg_pct / 100
        p_survive = 1 - p_fail
        p_0_fail = p_survive^n
        p_1_fail = n * p_fail * (p_survive^(n-1))
        p_array_fail = 1 - p_0_fail - p_1_fail
        printf "%.3f", p_array_fail * 100
    }'
}
