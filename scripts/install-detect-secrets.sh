#!/bin/bash

# Script to install detect-secrets and configure pre-commit hook

echo "Installing detect-secrets pre-commit hook..."

# Check if python3 is available
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    echo "Found python3"
elif command -v python &> /dev/null; then
    # Check if python points to version 3.x
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ $PYTHON_VERSION == *"Python 3."* ]]; then
        PYTHON_CMD="python"
        echo "Found python (version 3.x)"
    else
        echo "ERROR: Python 3 is required but not found on PATH"
        echo "Found: $PYTHON_VERSION"
        exit 1
    fi
else
    echo "ERROR: Python is not found on PATH"
    exit 1
fi

# Install detect-secrets
echo "Installing detect-secrets via pip..."
$PYTHON_CMD -m pip install detect-secrets
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install detect-secrets"
    exit 1
fi
echo "detect-secrets installed successfully"

# Configure pre-commit hook
PRE_COMMIT_PATH=".git/hooks/pre-commit"
HOOK_CONTENT='######## DETECT-SECRETS-HOOK START ########

echo "Running detect-secrets-hook"

git diff --staged --name-only -z | xargs -0 detect-secrets-hook --baseline .secrets.baseline --exclude-files package-lock.json

echo "Completed detect-secrets-hook"

####### DETECT-SECRETS-HOOK END #######'

if [ -f "$PRE_COMMIT_PATH" ]; then
    echo "Pre-commit hook file exists, updating..."

    # Check if detect-secrets hook already exists
    if grep -q "DETECT-SECRETS-HOOK START" "$PRE_COMMIT_PATH"; then
        echo "detect-secrets hook already exists in pre-commit file"
    else
        # Insert after #!/bin/sh if it exists, otherwise at the beginning
        if grep -q "^#!/bin/sh" "$PRE_COMMIT_PATH"; then
            # Create temporary file with new content
            awk -v hook="$HOOK_CONTENT" '/^#!\/bin\/sh/ {print; print ""; print hook; print ""; next} 1' "$PRE_COMMIT_PATH" > "$PRE_COMMIT_PATH.tmp"
            mv "$PRE_COMMIT_PATH.tmp" "$PRE_COMMIT_PATH"
        else
            # Prepend the hook content
            echo -e "$HOOK_CONTENT\n\n$(cat $PRE_COMMIT_PATH)" > "$PRE_COMMIT_PATH"
        fi
        echo "Pre-commit hook updated successfully"
    fi
else
    echo "Creating new pre-commit hook..."
    # Ensure the hooks directory exists
    mkdir -p "$(dirname "$PRE_COMMIT_PATH")"

    cat > "$PRE_COMMIT_PATH" << 'EOF'
#!/bin/sh

######## DETECT-SECRETS-HOOK START ########

echo "Running detect-secrets-hook"

git diff --staged --name-only -z | xargs -0 detect-secrets-hook --baseline .secrets.baseline --exclude-files package-lock.json

echo "Completed detect-secrets-hook"

####### DETECT-SECRETS-HOOK END #######
EOF
    chmod +x "$PRE_COMMIT_PATH"
    echo "Pre-commit hook created successfully"
fi

# Make sure the pre-commit hook is executable
chmod +x "$PRE_COMMIT_PATH"

echo ""
echo "detect-secrets pre-commit hook installation complete!"

