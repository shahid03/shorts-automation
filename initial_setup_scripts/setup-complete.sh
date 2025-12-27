#!/bin/bash

echo "🏛️ Setting up Stoic Shorts Automation..."

# Create all directories
mkdir -p config src/services src/utils data/stoic_shorts/{images,voiceovers,videos} logs

# Download all files from the artifacts above
# Copy each file content from the three setup scripts I provided

# Install dependencies
npm install

# Setup environment
cp .env.example .env

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env with your API keys"
echo "2. Add credentials to config/"
echo "3. Run: npm start"

