#!/bin/sh

echo "Traefik entrypoint script starting..."
echo "ACME_EMAIL value: '${ACME_EMAIL}'"

# Update traefik.yml with ACME_EMAIL if provided
if [ ! -z "${ACME_EMAIL}" ] && [ "${ACME_EMAIL}" != "" ]; then
  echo "Updating traefik.yml with ACME_EMAIL: ${ACME_EMAIL}"
  
  # Update the traefik configuration file
  if [ -f "/etc/traefik/traefik.yml" ]; then
    echo "Found traefik.yml at /etc/traefik/traefik.yml"
    
    # Copy the file to a writable location within the container
    cp "/etc/traefik/traefik.yml" "/tmp/traefik.yml"
    
    # Replace the placeholder with the ACME_EMAIL environment variable
    sed -i "s|{{ACME_EMAIL}}|${ACME_EMAIL}|g" "/tmp/traefik.yml"
    
    # Debug: Show the modified content
    echo "Modified traefik.yml content:"
    grep -n "email:" "/tmp/traefik.yml" || echo "No email lines found"
    
    # Verify the replacement worked
    if grep -q "${ACME_EMAIL}" "/tmp/traefik.yml"; then
      echo "Successfully updated traefik.yml with ACME_EMAIL: ${ACME_EMAIL}"
      # Copy the modified file back to the original location (force overwrite)
      cp -f "/tmp/traefik.yml" "/etc/traefik/traefik.yml"
      
      # Final verification that the file was copied correctly
      if grep -q "${ACME_EMAIL}" "/etc/traefik/traefik.yml"; then
        echo "Final verification: traefik.yml contains ACME_EMAIL: ${ACME_EMAIL}"
      else
        echo "Error: Final verification failed - ACME_EMAIL not found in /etc/traefik/traefik.yml"
        exit 1
      fi
    else
      echo "Warning: Replacement may not have worked, checking for {{ACME_EMAIL}} placeholder"
      if grep -q "{{ACME_EMAIL}}" "/tmp/traefik.yml"; then
        echo "Error: {{ACME_EMAIL}} placeholder still found in traefik.yml"
        exit 1
      fi
    fi
  else
    echo "Error: traefik.yml not found at /etc/traefik/traefik.yml"
    exit 1
  fi
else
  echo "ACME_EMAIL not set or empty, using default configuration"
  echo "Available environment variables:"
  env | grep -i acme || echo "No ACME_EMAIL found in environment"
fi

echo "Starting Traefik..."
exec traefik "$@" 
