#!/usr/bin/env bash
# Quick ESLint Fix for trailing spaces and newline

echo "🔧 Fixing trailing spaces and newline..."

# Navigate to functions directory
cd functions

# Auto-fix all formatting issues
npm run lint -- --fix

# Build and deploy
npm run build
cd ..

# Deploy functions
firebase deploy --only functions

echo "✅ Fixed and deployed!"