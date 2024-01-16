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

sendNotification() {
    # Extract the arguments to variables for clarity
    local vmid="$1"
    local old_status="$2"
    local new_status="$3"

    # Use the variables in the curl command
    # Implement Push-A-Tron notifications if you want
    # https://pushatron.com/
    #curl --location 'https://api.pushatron.com/sendNotifications' \
    #--header 'Content-Type: application/json' \
    #--data '{
    #    "project": "[PROJECT-ID]",
    #    "title": "Status Update",
    #    "message": "Status of VMID '"$vmid"' has changed from '"$old_status"' to '"$new_status"'.",
    #    "apikey": "[YOUR-API-KEY]"
    #}' > /dev/null

    echo "Notification: Status of VMID $1 has changed from $2 to $3."
}

# Main script starts here

# Centralize current data
centralize_data

# Check if previous state file exists
if [ -f "/tmp/psck_previous.txt" ]; then
    # Compare current state with previous state
    while read -r vmid name status; do
        # Look for the same VMID in the previous state
        previous_status=$(grep "^$vmid " /tmp/psck_previous.txt | awk '{print $3}')
        if [ "$previous_status" != "" ] && [ "$status" != "$previous_status" ]; then
            # Status has changed, call notification function
            sendNotification "$name($vmid)" "$previous_status" "$status"
        fi
    done < /tmp/psck_current.txt
fi

# Save current state as previous state for next run
mv /tmp/psck_current.txt /tmp/psck_previous.txt
