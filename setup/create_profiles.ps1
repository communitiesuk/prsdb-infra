# Define the profiles template filename and find the path based on the scripts location
$template = "profile-template"
$mfaSerialPlaceholder="<your-mfa-serial>"
$templateDirectory=split-path -parent $MyInvocation.MyCommand.Definition

# Check if the template file exists
if (-not (Test-Path "$templateDirectory\$template")) {
    Write-Host "Template file '$template' not found!"
    exit 1
}

# Check if user mfa_profile is provided
if ($args.Count -eq 0) {
    Write-Host "Usage: ./create_profiles.ps1 'Your mfa_serial'"
    exit 1
}

# Set the mfa_serial from the first argument
$mfaSerial = $args[0]

# Set the destination folder to default if none is provided
if ($args.Count -eq 1) {
    $destination = "$HOME/.aws/config"
} else {
    $destination = $args[1]
}

# Check if aws config is already present
if (Test-Path -Path $destination -PathType Leaf){
    Write-Host "An aws config is already present at $destination, cannot create config. Create the config file somewhere else and copy it to the end of the existing file."
    if ($args.Count -eq 2) {
        Write-Host "To create it elsewhere, set a custom destination, using: $0 'Your mfa_serial' 'Your custom destination'"
    } else {
        Write-Host "To create it elsewhere, set a different destination"
    }
    exit 1
}

# Copy the template to the new config file
cp "$templateDirectory/$template" $destination

if (-not ($?)){
    Write-Host "Could not create config file"
    exit 1
}

# Update the the config to replace the mfa serial placeholder with the mfa serial provided 
(Get-Content "$destination") -replace [regex]::Escape($mfaSerialPlaceholder), $mfaSerial | Set-Content "$destination"

if  (-not ($?)){
    Write-Host "Could not update config file with mfa_serial, deleting"
    rm "$destination"
    exit 1
}

# Confirmation message
Write-Host "aws config created: $destination"