#!/bin/bash
# SMART data parsing functions

parse_smart_data() {
    local input_data="$1"
    
    # Initialize temp files
    > /tmp/drive_tiers.tmp
    > /tmp/smart_comparison.tmp
    
    if [ "$input_data" != "mock" ]; then
        # Parse real SMART data
        echo "$input_data" | awk -v FS=":" '
        /^PdId/ {
            if (pdid != "") {
                age_years = poh/8760
                printf "%s,%s,%s,%d,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.2f,%.2f\n", \
                    pdid, model, health, temp, age_years, realloc, pending, offline, poh, \
                    raw_read_error, seek_error, spin_retry, start_stop, power_cycle, \
                    uncorr_error, crc_error, load_cycle, gsense_error, temp_min, \
                    total_lbas_written/1000000000, total_lbas_read/1000000000
            }
            pdid=$2; gsub(/^[ \t]+|[ \t]+$/,"",pdid)
            model=""; health=""; temp=0; poh=0
            realloc=0; pending=0; offline=0
            raw_read_error=0; seek_error=0; spin_retry=0; start_stop=0
            power_cycle=0; uncorr_error=0; crc_error=0; load_cycle=0
            gsense_error=0; temp_min=0; total_lbas_written=0; total_lbas_read=0
            next
        }
        /^Model Number/ { model=$2; gsub(/^[ \t]+|[ \t]+$/,"",model) }
        /^SMART Health Status/ { health=$2; gsub(/^[ \t]+|[ \t]+$/,"",health) }
        /^Current Temperature/ { temp=$2; gsub(/[^0-9]/,"",temp) }
        /^Lifetime.*Min\/Max Temperature/ { 
          #broken  if (match($0, /([0-9]+)\/[0-9]+/, arr)) temp_min = arr[1]
        }
        /^  1 Raw_Read_Error_Rate/ { getline; n=split($0,a," "); raw_read_error=a[n]+0 }
        /^  4 Start_Stop_Count/ { getline; n=split($0,a," "); start_stop=a[n]+0 }
        /^  5 Reallocated_Sector_Ct/ { getline; n=split($0,a," "); realloc=a[n]+0 }
        /^  7 Seek_Error_Rate/ { getline; n=split($0,a," "); seek_error=a[n]+0 }
        /^  9 Power_On_Hours/ { getline; n=split($0,a," "); poh=a[n]+0 }
        /^ 10 Spin_Retry_Count/ { getline; n=split($0,a," "); spin_retry=a[n]+0 }
        /^ 12 Power_Cycle_Count/ { getline; n=split($0,a," "); power_cycle=a[n]+0 }
        /^187 Uncorrectable_Error_Count/ { getline; n=split($0,a," "); uncorr_error=a[n]+0 }
        /^191 G-Sense_Error_Rate/ { getline; n=split($0,a," "); gsense_error=a[n]+0 }
        /^193 Load_Cycle_Count/ { getline; n=split($0,a," "); load_cycle=a[n]+0 }
        /^197 Current_Pending_Sector/ { getline; n=split($0,a," "); pending=a[n]+0 }
        /^198 Offline_Uncorrectable/ { getline; n=split($0,a," "); offline=a[n]+0 }
        /^199 UDMA_CRC_Error_Count/ { getline; n=split($0,a," "); crc_error=a[n]+0 }
        /^241 Total_LBAs_Written/ { getline; n=split($0,a," "); total_lbas_written=a[n]+0 }
        /^242 Total_LBAs_Read/ { getline; n=split($0,a," "); total_lbas_read=a[n]+0 }
        END {
            if (pdid != "") {
                age_years = poh/8760
                printf "%s,%s,%s,%d,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.2f,%.2f\n", \
                    pdid, model, health, temp, age_years, realloc, pending, offline, poh, \
                    raw_read_error, seek_error, spin_retry, start_stop, power_cycle, \
                    uncorr_error, crc_error, load_cycle, gsense_error, temp_min, \
                    total_lbas_written/1000000000, total_lbas_read/1000000000
            }
        }' > /tmp/parsed_drives.tmp
    else
        # Use mock data for testing
        cat > /tmp/parsed_drives.tmp << 'EOF'
1,ST4000VN008-2DR1,OK,34,1.9,0,0,0,16580,145525859,105639637,0,2823,37,0,0,3099,0,25,26.65,99.85
2,ST4000DM000-1F21,OK,34,3.3,0,0,0,28908,89234567,87456123,0,4521,89,0,0,5678,0,22,45.23,178.92
3,ST4000DM000-1F21,OK,33,3.9,2,0,0,34164,156789234,145623789,0,5234,98,0,0,6789,0,19,67.45,234.56
4,ST4000DM000-1F21,OK,33,3.9,0,1,0,34164,134567890,123456789,0,5123,97,0,1,6543,0,18,65.78,228.34
5,ST4000DM000-1F21,OK,34,3.9,0,0,0,34164,98765432,98765432,0,5089,96,0,0,6234,0,20,64.12,225.67
6,ST4000VN008-2DR1,OK,33,1.7,0,0,0,14892,123456789,89123456,0,2456,34,0,0,2789,0,26,24.56,87.34
EOF
    fi
}
