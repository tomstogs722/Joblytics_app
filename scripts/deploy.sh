#!/bin/bash
set -e

# Configuration
BACKEND_APP_RUNNER_SERVICE="kpi-dashboard-backend"
FRONTEND_APP_RUNNER_SERVICE="kpi-dashboard-frontend"
AWS_REGION="us-east-1"
ECR_REPOSITORY_BACKEND="kpi-dashboard-backend"
ECR_REPOSITORY_FRONTEND="kpi-dashboard-frontend"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   KPI Dashboard Deployment Script     ${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}AWS credentials are not configured or invalid.${NC}"
    exit 1
fi
echo -e "${GREEN}AWS credentials validated.${NC}"

# Get the ECR login token
echo -e "${YELLOW}Logging in to Amazon ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo -e "${GREEN}Successfully logged in to ECR.${NC}"

# Build and push backend image
echo -e "${YELLOW}Building and pushing backend image...${NC}"
cd ../backend
docker build -t $ECR_REPOSITORY_BACKEND:latest .
docker tag $ECR_REPOSITORY_BACKEND:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_BACKEND:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_BACKEND:latest
echo -e "${GREEN}Backend image pushed successfully.${NC}"

# Build and push frontend image
echo -e "${YELLOW}Building and pushing frontend image...${NC}"
cd ../frontend
docker build -t $ECR_REPOSITORY_FRONTEND:latest .
docker tag $ECR_REPOSITORY_FRONTEND:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_FRONTEND:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_FRONTEND:latest
echo -e "${GREEN}Frontend image pushed successfully.${NC}"

# Update App Runner services
echo -e "${YELLOW}Updating App Runner services...${NC}"

# Update backend service
echo -e "${YELLOW}Updating backend service...${NC}"
aws apprunner update-service \
    --service-name $BACKEND_APP_RUNNER_SERVICE \
    --source-configuration "ImageRepository={ImageIdentifier=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_BACKEND:latest,ImageConfiguration={Port=3000},ImageRepositoryType=ECR}" \
    --region $AWS_REGION

# Wait for backend service update to complete
echo -e "${YELLOW}Waiting for backend service update to complete...${NC}"
aws apprunner wait service-updated \
    --service-name $BACKEND_APP_RUNNER_SERVICE \
    --region $AWS_REGION

# Update frontend service
echo -e "${YELLOW}Updating frontend service...${NC}"
aws apprunner update-service \
    --service-name $FRONTEND_APP_RUNNER_SERVICE \
    --source-configuration "ImageRepository={ImageIdentifier=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_FRONTEND:latest,ImageConfiguration={Port=80},ImageRepositoryType=ECR}" \
    --region $AWS_REGION

# Wait for frontend service update to complete
echo -e "${YELLOW}Waiting for frontend service update to complete...${NC}"
aws apprunner wait service-updated \
    --service-name $FRONTEND_APP_RUNNER_SERVICE \
    --region $AWS_REGION

# Get service URLs
BACKEND_URL=$(aws apprunner describe-service --service-name $BACKEND_APP_RUNNER_SERVICE --region $AWS_REGION --query "Service.ServiceUrl" --output text)
FRONTEND_URL=$(aws apprunner describe-service --service-name $FRONTEND_APP_RUNNER_SERVICE --region $AWS_REGION --query "Service.ServiceUrl" --output text)

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
BACKEND_HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$BACKEND_URL/health)
FRONTEND_HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$FRONTEND_URL/health.html)

if [ "$BACKEND_HEALTH_STATUS" == "200" ] && [ "$FRONTEND_HEALTH_STATUS" == "200" ]; then
    echo -e "${GREEN}Deployment verified successfully!${NC}"
    echo -e "${GREEN}Backend URL: https://$BACKEND_URL${NC}"
    echo -e "${GREEN}Frontend URL: https://$FRONTEND_URL${NC}"
else
    echo -e "${RED}Deployment verification failed.${NC}"
    echo -e "${RED}Backend health check status: $BACKEND_HEALTH_STATUS${NC}"
    echo -e "${RED}Frontend health check status: $FRONTEND_HEALTH_STATUS${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
