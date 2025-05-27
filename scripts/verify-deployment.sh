#!/bin/bash
set -e

# Configuration
BACKEND_URL=""
FRONTEND_URL=""
MAX_RETRIES=10
RETRY_INTERVAL=30

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   KPI Dashboard Deployment Verifier   ${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Function to display usage
usage() {
  echo "Usage: $0 -b <backend_url> -f <frontend_url>"
  echo "  -b, --backend-url    Backend URL to verify"
  echo "  -f, --frontend-url   Frontend URL to verify"
  echo "  -h, --help           Display this help message"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -b|--backend-url)
      BACKEND_URL="$2"
      shift
      shift
      ;;
    -f|--frontend-url)
      FRONTEND_URL="$2"
      shift
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Check if required parameters are provided
if [ -z "$BACKEND_URL" ] || [ -z "$FRONTEND_URL" ]; then
  echo -e "${RED}Error: Backend URL and Frontend URL are required.${NC}"
  usage
fi

# Function to verify endpoint with retries
verify_endpoint() {
  local url=$1
  local endpoint=$2
  local description=$3
  local retries=0
  local full_url="${url}${endpoint}"
  
  echo -e "${YELLOW}Verifying ${description} at ${full_url}...${NC}"
  
  while [ $retries -lt $MAX_RETRIES ]; do
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "${full_url}")
    
    if [ "$status_code" == "200" ]; then
      echo -e "${GREEN}✓ ${description} is available (HTTP ${status_code})${NC}"
      return 0
    else
      retries=$((retries+1))
      echo -e "${YELLOW}Attempt ${retries}/${MAX_RETRIES}: ${description} returned HTTP ${status_code}, retrying in ${RETRY_INTERVAL} seconds...${NC}"
      sleep $RETRY_INTERVAL
    fi
  done
  
  echo -e "${RED}✗ ${description} verification failed after ${MAX_RETRIES} attempts${NC}"
  return 1
}

# Function to verify API endpoints
verify_api_endpoints() {
  local success=true
  
  # Verify health endpoint
  if ! verify_endpoint "$BACKEND_URL" "/health" "Backend health check"; then
    success=false
  fi
  
  # Verify comprehensive health endpoint
  if ! verify_endpoint "$BACKEND_URL" "/health/comprehensive" "Backend comprehensive health check"; then
    success=false
  fi
  
  # Verify API documentation
  if ! verify_endpoint "$BACKEND_URL" "/api-docs" "API documentation"; then
    success=false
  fi
  
  # Verify authentication endpoint
  if ! verify_endpoint "$BACKEND_URL" "/auth/status" "Authentication status"; then
    success=false
  fi
  
  if [ "$success" = true ]; then
    echo -e "${GREEN}All backend endpoints verified successfully!${NC}"
    return 0
  else
    echo -e "${RED}Some backend endpoints failed verification.${NC}"
    return 1
  fi
}

# Function to verify frontend
verify_frontend() {
  local success=true
  
  # Verify frontend health check
  if ! verify_endpoint "$FRONTEND_URL" "/health.html" "Frontend health check"; then
    success=false
  fi
  
  # Verify main page loads
  if ! verify_endpoint "$FRONTEND_URL" "/" "Frontend main page"; then
    success=false
  fi
  
  # Verify static assets
  if ! verify_endpoint "$FRONTEND_URL" "/static/js/main.js" "Frontend static assets"; then
    success=false
  fi
  
  if [ "$success" = true ]; then
    echo -e "${GREEN}All frontend endpoints verified successfully!${NC}"
    return 0
  else
    echo -e "${RED}Some frontend endpoints failed verification.${NC}"
    return 1
  fi
}

# Main verification process
echo -e "${YELLOW}Starting deployment verification...${NC}"

backend_success=true
frontend_success=true

# Verify backend
echo -e "${YELLOW}Verifying backend deployment...${NC}"
if ! verify_api_endpoints; then
  backend_success=false
fi

# Verify frontend
echo -e "${YELLOW}Verifying frontend deployment...${NC}"
if ! verify_frontend; then
  frontend_success=false
fi

# Final verification result
if [ "$backend_success" = true ] && [ "$frontend_success" = true ]; then
  echo -e "${GREEN}Deployment verification completed successfully!${NC}"
  exit 0
else
  echo -e "${RED}Deployment verification failed.${NC}"
  exit 1
fi
