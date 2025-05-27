#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   KPI Dashboard Test Runner Script    ${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Function to run tests with proper error handling
run_tests() {
  local project_dir=$1
  local project_name=$2
  
  echo -e "${YELLOW}Running tests for ${project_name}...${NC}"
  
  cd "$project_dir"
  
  # Check if project has tests
  if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found in ${project_dir}${NC}"
    return 1
  fi
  
  # Install dependencies if node_modules doesn't exist
  if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm ci
  fi
  
  # Run linting
  if npm run | grep -q "lint"; then
    echo -e "${YELLOW}Running linting...${NC}"
    npm run lint
  else
    echo -e "${YELLOW}Skipping linting (no lint script found)${NC}"
  fi
  
  # Run tests
  if npm run | grep -q "test:cov"; then
    echo -e "${YELLOW}Running tests with coverage...${NC}"
    npm run test:cov
  elif npm run | grep -q "test"; then
    echo -e "${YELLOW}Running tests...${NC}"
    npm run test
  else
    echo -e "${RED}No test script found in package.json${NC}"
    return 1
  fi
  
  echo -e "${GREEN}All tests passed for ${project_name}!${NC}"
  return 0
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Run backend tests
if ! run_tests "${PROJECT_ROOT}/backend" "Backend"; then
  echo -e "${RED}Backend tests failed!${NC}"
  exit 1
fi

# Run frontend tests
if ! run_tests "${PROJECT_ROOT}/frontend" "Frontend"; then
  echo -e "${RED}Frontend tests failed!${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed successfully!${NC}"
exit 0
