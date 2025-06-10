#!/usr/bin/env bash
# Troubleshoot Auth Function Deployment

echo "🔍 Troubleshooting initializeUserPreferences function..."

# 1. Check the full deployment status
firebase functions:list

# 2. Check for specific error details
echo "📋 Checking deployment logs..."
firebase functions:log --only initializeUserPreferences

# 3. Check if IAM APIs are enabled
echo "🔑 Checking required APIs..."
gcloud services list --enabled --project=rivr-official | grep -E "(iam|admin|auth)"

# 4. Try deploying just the failing function with more verbose output
echo "🚀 Attempting to redeploy the failing function..."
firebase deploy --only functions:initializeUserPreferences --debug

# 5. Alternative: Skip the auth functions for now and test core functionality
echo ""
echo "📝 Alternative approach if auth function continues to fail:"
echo "1. Comment out the auth functions temporarily"
echo "2. Deploy the core notification functions"
echo "3. Test the notification system"
echo "4. Add auth functions back later"

echo ""
echo "✅ SUCCESSFUL DEPLOYMENTS:"
echo "  - healthCheck (v2 HTTP) ✅"
echo "  - testDatabase (v2 HTTP) ✅" 
echo "  - testScheduledFunction (v2 Scheduler) ✅"
echo "  - monitorFlowConditions (v2 Scheduler) ✅"
echo "  - processThresholdUpdates (v2 Firestore) ✅"
echo "  - recordThesisMetrics (v2 Callable) ✅"
echo "  - sendTestNotification (v2 Callable) ✅"
echo "  - updateFCMToken (v2 Callable) ✅"

echo ""
echo "⚠️  FAILED DEPLOYMENT:"
echo "  - initializeUserPreferences (v1 Auth) ❌"
echo "  - cleanupUserData (v1 Auth) - unknown status"

echo ""
echo "🧪 Test your core functionality:"
echo "curl https://us-central1-rivr-official.cloudfunctions.net/healthCheck"