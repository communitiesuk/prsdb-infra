#!/bin/bash

# Define the profiles template filename and find the path based on the scripts location
TEMPLATE="profile-template"
TEMPLATE_DIR=$(dirname "$0")
MFA_SERIAL_PLACEHOLDER="<your-mfa-serial>"

# Check if template exists
if [ ! -f "$TEMPLATE_DIR/$TEMPLATE" ]; then
  echo "Template file '$TEMPLATE' not found!"
  echo "It should be in the same directory as this script"
  exit 1
fi

# Check if user mfa_profile is provided
if [ -z "$1" ]; then
  echo "Usage: $0 \"Your mfa_serial\""
  exit 1
fi

# Set the destination folder to default if none is provided
DESTINATION=${2:-"$HOME/.aws/config"}

# Check if aws config is already present
if [ -f "$DESTINATION" ]; then
  echo "An aws config is already present at $DESTINATION, delete it and retry"
  if [ -z "$2" ]; then
    echo "or set a custom destination, using: $0 \"Your mfa_serial\" \"Your custom destination\""
  else
    echo "or set a different destination"
  fi
  exit 1
fi

# Copy the template to the new ADR file
cp "$TEMPLATE_DIR/$TEMPLATE" $DESTINATION

if [ $? != 0 ]; then
  echo "Could not create config file"
  exit 1
fi

# Update the the config to replace the mfa serial placeholder with the mfa serial provided 
sed -i "s|$MFA_SERIAL_PLACEHOLDER|$1|g" "$DESTINATION"

if [ "$?" != 0 ]; then
  echo "Could not update config file with mfa_serial, deleting"
  rm "$DESTINATION"
  exit 1
fi

# Confirmation message
echo "aws config created: $DESTINATION"
