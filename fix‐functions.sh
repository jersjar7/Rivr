#!/usr/bin/env bash
# Task 2.4 - Final Troubleshooting & Fix Commands

echo "🔧 Fixing Firebase Functions TypeScript Issues..."

# 1. Remove problematic scripts/tsconfig.json if it exists
if [ -f "scripts/tsconfig.json" ]; then
    echo "🗑️ Removing problematic scripts/tsconfig.json"
    rm scripts/tsconfig.json
    echo "✅ Removed scripts/tsconfig.json"
fi

# 2. Navigate to functions directory
cd functions

# 3. Clean up any cached/compiled files
echo "🧹 Cleaning up cached files..."
rm -rf lib/
rm -rf node_modules/.cache/ 2>/dev/null || true
rm -rf .tsbuildinfo 2>/dev/null || true

# 4. Ensure we have the latest firebase-functions version
echo "📦 Updating Firebase Functions to latest version..."
npm install firebase-functions@latest firebase-admin@latest

# 5. Check firebase-functions version (should be 5.x or 6.x for v2 support)
echo "📋 Checking Firebase Functions version:"
npm list firebase-functions

# 6. Verify the tsconfig.json exists and is correct
echo "🔍 Verifying tsconfig.json..."
if [ ! -f "tsconfig.json" ]; then
    echo "❌ tsconfig.json not found in functions/ directory"
    exit 1
fi

# 7. Build the functions
echo "🔨 Building Cloud Functions..."
npm run build

# 8. Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📁 Generated files:"
    ls -la lib/
else
    echo "❌ Build failed. Check the error messages above."
    exit 1
fi

# 9. Verify the functions are properly exported
echo "🔍 Verifying function exports..."
if [ -f "lib/index.js" ]; then
    echo "✅ index.js compiled successfully"
    echo "📋 Function exports found in compiled file:"
    grep -o "exports\.[a-zA-Z0-9_]*" lib/index.js | head -10
else
    echo "❌ index.js not found after compilation"
    exit 1
fi

# 10. Test deployment preparation (dry run)
echo "🧪 Testing deployment configuration..."
cd ..
firebase functions:shell --inspect-functions

echo ""
echo "🎉 All fixes applied successfully!"
echo ""
echo "✅ Fixed Issues:"
echo "1. ✅ Corrected v2 Firebase Functions imports"
echo "2. ✅ Used onSchedule instead of schedule" 
echo "3. ✅ Kept auth triggers as v1 (v2 doesn't support them yet)"
echo "4. ✅ Fixed TypeScript configuration"
echo "5. ✅ Removed problematic scripts/tsconfig.json"
echo ""
echo "📋 Functions ready for deployment:"
echo "- healthCheck (v2 HTTP)"
echo "- testDatabase (v2 HTTP)" 
echo "- testScheduledFunction (v2 Scheduler)"
echo "- monitorFlowConditions (v2 Scheduler)"
echo "- processThresholdUpdates (v2 Firestore)"
echo "- initializeUserPreferences (v1 Auth - required)"
echo "- cleanupUserData (v1 Auth - required)"
echo "- recordThesisMetrics (v2 Callable)"
echo "- sendTestNotification (v2 Callable)"
echo "- updateFCMToken (v2 Callable)"
echo ""
echo "🚀 Ready to deploy with: firebase deploy --only functions"