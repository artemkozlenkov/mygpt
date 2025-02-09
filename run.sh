#!/bin/bash

# Script to manage Docker Compose containers, run Gitleaks, and pre-commit-terraform.

# Define the compose file
COMPOSE_FILE="compose.yml"

# Define the pre-commit-terraform image tag
PRE_COMMIT_TERRAFORM_TAG="latest"  # Make this configurable if needed

# Function to check if Docker Compose is installed
check_docker_compose() {
  if ! command -v docker compose &> /dev/null; then
    echo "Error: docker compose is not installed."
    echo "Please install Docker Compose before running this script."
    exit 1
  fi
}

# Function to start containers
start_containers() {
  echo "Starting containers..."
  if docker compose -f "$COMPOSE_FILE" up -d; then
    echo "Containers started successfully."
  else
    echo "Failed to start containers."
    return 1
  fi
}

# Function to stop containers
stop_containers() {
  echo "Stopping containers..."
  if docker compose -f "$COMPOSE_FILE" down; then
    echo "Containers stopped successfully."
  else
    echo "Failed to stop containers."
    return 1
  fi
}

# Function to run Gitleaks
run_gitleaks() {
  echo "Running Gitleaks..."
  if docker run --rm -v "$(pwd):/app" -w /app zricethezav/gitleaks git -v; then
    echo "Gitleaks scan completed."
  else
    echo "Gitleaks scan failed."
    return 1
  fi
}

# Function to run pre-commit-terraform
run_pre_commit_terraform() {
  echo "Running pre-commit-terraform..."
  USERID=$(id -u):$(id -g)
  if docker run --rm -e "USERID=$USERID" -v "$(pwd):/lint" -w /lint ghcr.io/antonbabenko/pre-commit-terraform:"$PRE_COMMIT_TERRAFORM_TAG" run -a; then
    echo "pre-commit-terraform completed."
  else
    echo "pre-commit-terraform failed."
    return 1
  fi
}

# Function to display status of containers
status() {
    echo "Checking container status..."
    docker compose -f "$COMPOSE_FILE" ps
}

# Function to display usage instructions
usage() {
  echo "Usage: $0 {start|stop|gitleaks|pre-commit-terraform|status}"
  echo "  start                : Starts the Docker Compose containers."
  echo "  stop                 : Stops the Docker Compose containers."
  echo "  gitleaks             : Runs Gitleaks to scan for secrets."
  echo "  pre-commit-terraform : Runs pre-commit-terraform."
  echo "  status               : Shows the status of the Docker Compose containers."
  exit 1
}

# --- Main Script ---

# Check if Docker Compose is installed
check_docker_compose

# Check for command-line arguments
if [ "$#" -eq 0 ]; then
    usage
fi

case "$1" in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    gitleaks)
        run_gitleaks
        ;;
    pre-commit-terraform)
        run_pre_commit_terraform
        ;;
    status)
        status
        ;;
    *)
        echo "Invalid argument: $1"
        usage
        ;;
esac

exit $?