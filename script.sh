#!/bin/bash

# Function to centralize and format the output of qm and pct list commands
centralize_data() {
    # Extract and format data from 'qm list'
    qm list | tail -n +2 | awk '{print $1, $2, $3}' > /tmp/psck_current.txt

    # Extract and format data from 'pct list'
    # Adjust field positions based on whether 'Lock' column is empty or not
    # Might not be the best solution, works for now
    pct list | tail -n +2 | awk '{
        if (NF == 3) {  # If there are 3 fields, 'Lock' column is empty
            print $1, $3, $2
        } else {  # If there are more than 4 fields, 'Lock' column is present
            print $1, $4, $2
        }
    }' >> /tmp/psck_current.txt
}

sendInitialNotifications() {
    local message="SYSTEM INIT"

    while read -r vmid name status; do
        # Accumulate initial statuses in message
        message+="VMID $name($vmid) is currently $status. \n"
    done < /tmp/psck_current.txt

    # Send a single notification with all initial statuses
    if [ ! -z "$message" ]; then
        sendNotification "$message"
    fi
}

sendNotification() {
    # Extract the arguments to variables for clarity
    local message="$1"

    echo "$message"
    sendCurlNotification "Status Update" "$message"
}

sendCurlNotification() {
    local title="$1"
    local notification_body="$2"

    # Use the variables in the curl command
    # Implement Push-A-Tron notifications if you want
    # https://pushatron.com/

    # Use the variables in the curl command
    #curl -s -o /dev/null --location 'https://api.pushatron.com/sendNotifications' \
    #--header 'Content-Type: application/json' \
    #--data '{
    #    "title": "'"$title"'",
    #    "message": "'"$notification_body"'",
    #    "apikey": "[YOUR-API-KEY]",
    #    "project": "[PROJECT-ID]"
    #}'
}

# Centralize current data
centralize_data

# Check if previous state file exists
if [ -f "/tmp/psck_previous.txt" ]; then
    # Compare current state with previous state
    while read -r vmid name status; do
        # Look for the same VMID in the previous state
        previous_status=$(grep "^$vmid " /tmp/psck_previous.txt | awk '{print $3}')
        if [ "$previous_status" != "" ] && [ "$status" != "$previous_status" ]; then
            # Accumulate status changes in message
            message+="Status of VMID $name($vmid) has changed from $previous_status to $status.\n"
        fi
    done < /tmp/psck_current.txt

    # Send a single notification if there were any changes
    if [ ! -z "$message" ]; then
        sendNotification "$message"
    fi
else
    # Since previous state file doesn't exist, send notifications for all VMs
    sendInitialNotifications    
fi

# Save current state as previous state for next run
mv /tmp/psck_current.txt /tmp/psck_previous.txt
