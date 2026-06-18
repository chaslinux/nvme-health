#!/usr/bin/env bash
# NVMe health checker using nvme-cli

### Declare variables ###
DEVICE="${1:-/dev/nvme0n1}"
# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

if [ ! command -v nvme >/dev/null 2>&1 ]; then
    echo "nvme-cli tools not found, installing..."
    sudo apt install -y nvme-cli
fi

if [ ! -b "$DEVICE" ]; then
    echo "Error: $DEVICE is not a block device"
    exit 2
fi


DATA=$(sudo nvme smart-log "$DEVICE" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Unable to read NVMe SMART data"
    exit 2
fi


get_value() {
    echo "$DATA" | awk -F: -v key="$1" '
    $1 ~ key {
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        print $2
    }'
}


critical_warning=$(get_value "critical_warning")
media_errors=$(get_value "media_errors")
err_log=$(get_value "num_err_log_entries")
used=$(get_value "percentage_used")
spare=$(get_value "available_spare")


status_ok()
{
    echo -e "${GREEN}OK${RESET}"
}

status_warn()
{
    echo -e "${YELLOW}WARN${RESET}"
}

status_bad()
{
    echo -e "${RED}BAD${RESET}"
}


echo
echo -e "${BOLD}${BLUE}======================================${RESET}"
echo -e "${BOLD}        NVMe HEALTH REPORT${RESET}"
echo -e "${BOLD}${BLUE}======================================${RESET}"
echo
echo -e "Device: ${BOLD}$DEVICE${RESET}"
echo


# Critical warning
printf "%-28s " "Critical Warning:"
if [[ "$critical_warning" == "0x0" || "$critical_warning" == "0" ]]; then
    status_ok
else
    status_bad
fi
echo "   $critical_warning"


# Media errors
printf "%-28s " "Media Errors:"
if [[ "$media_errors" == "0" ]]; then
    status_ok
else
    status_bad
fi
echo "   $media_errors"


# Error log entries
printf "%-28s " "Error Log Entries:"
if [[ "$err_log" == "0" ]]; then
    status_ok
else
    status_warn
fi
echo "   $err_log"


# Percentage used
printf "%-28s " "Drive Wear:"
USED_NUM=$(echo "$used" | tr -dc '0-9')

if [ "$USED_NUM" -lt 80 ]; then
    status_ok
elif [ "$USED_NUM" -lt 95 ]; then
    status_warn
else
    status_bad
fi

echo "   $used"


# Spare
printf "%-28s " "Available Spare:"
SPARE_NUM=$(echo "$spare" | tr -dc '0-9')

if [ "$SPARE_NUM" -ge 10 ]; then
    status_ok
elif [ "$SPARE_NUM" -gt 0 ]; then
    status_warn
else
    status_bad
fi

echo "   $spare"


echo
echo -e "${BOLD}${BLUE}======================================${RESET}"


# Final exit status
if [[ "$critical_warning" != "0x0" && "$critical_warning" != "0" ]] ||
   [[ "$media_errors" != "0" ]] ||
   [[ "$SPARE_NUM" == "0" ]]; then
    echo -e "${RED}${BOLD}DRIVE HEALTH WARNING${RESET}"
    exit 1
else
    echo -e "${GREEN}${BOLD}DRIVE HEALTH OK${RESET}"
    exit 0
fi
