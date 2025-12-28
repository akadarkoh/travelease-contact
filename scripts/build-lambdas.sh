#!/bin/bash
set -e

echo "🔨 Building Lambda deployment packages..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to build a Lambda package
build_lambda() {
    local name=$1
    local dir=$2
    
    echo -e "\n${BLUE}Building ${name}...${NC}"
    
    cd "$dir"
    
    # Install dependencies if requirements.txt exists and has content
    if [ -s requirements.txt ]; then
        echo "Installing dependencies..."
        python3 -m pip install -r requirements.txt -t . --quiet
    fi
    
    # Create ZIP file
    echo "Creating ZIP package..."
    zip -r "../${name}.zip" . -x "*.pyc" -x "__pycache__/*" > /dev/null
    
    cd - > /dev/null
    
    echo -e "${GREEN}✅ ${name}.zip created${NC}"
}

# Navigate to project root
cd "$(dirname "$0")/.."

# Build each Lambda function
build_lambda "submit-handler" "lambda/submit-handler"
build_lambda "client-handler" "lambda/client-handler"
build_lambda "business-handler" "lambda/business-handler"

echo -e "\n${GREEN}🎉 All Lambda packages built successfully!${NC}"
echo -e "\nPackages created:"
ls -lh lambda/*.zip