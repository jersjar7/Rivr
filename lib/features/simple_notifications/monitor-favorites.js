// functions/src/simple-notifications/monitor-favorites.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Scheduled function to monitor favorite rivers for flow alerts
 * Runs every 30 minutes to check NOAA forecasts against return periods
 */
exports.monitorFavoriteRivers = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    console.log('🔍 Starting scheduled flow monitoring...');
    
    try {
      // Get all users with active notification preferences
      const activeUsers = await getActiveNotificationUsers();
      
      if (activeUsers.length === 0) {
        console.log('ℹ️ No users with active notifications found');
        return null;
      }

      console.log(`👥 Found ${activeUsers.length} users with active notifications`);

      // Process each user's favorite rivers
      const results = await Promise.allSettled(
        activeUsers.map(user => monitorUserRivers(user))
      );

      // Log results
      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.filter(r => r.status === 'rejected').length;

      console.log(`✅ Monitoring completed: ${successful} successful, ${failed} failed`);
      
      return null;
    } catch (error) {
      console.error('❌ Error in scheduled flow monitoring:', error);
      throw error;
    }
  });

/**
 * HTTP function to manually trigger flow monitoring (for testing/debugging)
 */
exports.triggerFlowMonitoring = functions.https.onCall(async (data, context) => {
  // Verify authentication for manual triggers
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  console.log('🧪 Manual flow monitoring triggered by user:', context.auth.uid);

  try {
    const userId = data.userId || context.auth.uid;
    
    // Monitor specific user or all users
    if (userId === 'all') {
      const activeUsers = await getActiveNotificationUsers();
      const results = await Promise.allSettled(
        activeUsers.map(user => monitorUserRivers(user))
      );
      
      return {
        success: true,
        usersProcessed: activeUsers.length,
        results: results.map(r => r.status)
      };
    } else {
      const user = await getUserPreferences(userId);
      if (user) {
        await monitorUserRivers(user);
        return { success: true, userProcessed: userId };
      } else {
        return { success: false, error: 'User not found or notifications disabled' };
      }
    }
  } catch (error) {
    console.error('❌ Error in manual trigger:', error);
    throw new functions.https.HttpsError('internal', 'Monitoring failed');
  }
});

/**
 * Get all users with active notification preferences
 */
async function getActiveNotificationUsers() {
  try {
    const snapshot = await db
      .collection('simpleNotificationPreferences')
      .where('enabled', '==', true)
      .get();

    const activeUsers = [];
    
    for (const doc of snapshot.docs) {
      try {
        const preferences = doc.data();
        
        // Only include users with rivers to monitor and within notification hours
        if (preferences.monitoredRiverIds && 
            preferences.monitoredRiverIds.length > 0 && 
            shouldSendNotificationNow(preferences)) {
          activeUsers.push({
            ...preferences,
            userId: doc.id
          });
        }
      } catch (error) {
        console.warn(`⚠️ Error parsing preferences for ${doc.id}:`, error);
      }
    }

    return activeUsers;
  } catch (error) {
    console.error('❌ Error getting active users:', error);
    return [];
  }
}

/**
 * Get specific user's notification preferences
 */
async function getUserPreferences(userId) {
  try {
    const doc = await db
      .collection('simpleNotificationPreferences')
      .doc(userId)
      .get();

    if (doc.exists) {
      const data = doc.data();
      return {
        ...data,
        userId: doc.id
      };
    }
    return null;
  } catch (error) {
    console.error(`❌ Error getting user preferences for ${userId}:`, error);
    return null;
  }
}

/**
 * Check if notifications should be sent now (considering quiet hours)
 */
function shouldSendNotificationNow(preferences) {
  if (!preferences.enabled) return false;
  if (!preferences.quietHoursEnabled) return true;

  const now = new Date();
  const currentHour = now.getHours();
  const { quietHourStart = 22, quietHourEnd = 7 } = preferences;

  // Handle quiet hours that cross midnight
  if (quietHourStart > quietHourEnd) {
    return !(currentHour >= quietHourStart || currentHour < quietHourEnd);
  } else {
    return !(currentHour >= quietHourStart && currentHour < quietHourEnd);
  }
}

/**
 * Monitor rivers for a specific user
 */
async function monitorUserRivers(userPreferences) {
  console.log(`🌊 Monitoring ${userPreferences.monitoredRiverIds.length} rivers for user ${userPreferences.userId}`);

  const alerts = [];

  for (const riverId of userPreferences.monitoredRiverIds) {
    try {
      const riverAlerts = await checkRiverForAlerts(riverId, userPreferences);
      alerts.push(...riverAlerts);
    } catch (error) {
      console.warn(`⚠️ Error checking river ${riverId}:`, error);
    }
  }

  // Send notifications for any alerts found
  for (const alert of alerts) {
    await processAlert(alert);
  }

  console.log(`✅ User ${userPreferences.userId}: ${alerts.length} alerts processed`);
  return alerts.length;
}

/**
 * Check a specific river for flow alerts
 */
async function checkRiverForAlerts(riverId, userPreferences) {
  try {
    // Get flow forecast data
    const flowData = await getFlowForecastData(riverId);
    if (!flowData) {
      console.warn(`⚠️ No flow data available for river ${riverId}`);
      return [];
    }

    // Get return period data
    const returnPeriods = await getReturnPeriodData(riverId);
    if (!returnPeriods) {
      console.warn(`⚠️ No return period data available for river ${riverId}`);
      return [];
    }

    // Get river name
    const riverName = await getRiverName(riverId);

    // Check forecasts against return periods
    const alerts = checkForecastsAgainstReturnPeriods(
      flowData,
      returnPeriods,
      userPreferences,
      riverName
    );

    return alerts;
  } catch (error) {
    console.error(`❌ Error checking river ${riverId}:`, error);
    return [];
  }
}

/**
 * Get flow forecast data (cached or fresh from NOAA)
 */
async function getFlowForecastData(riverId) {
  try {
    // First try cache
    const cachedData = await getCachedFlowData(riverId);
    if (cachedData && isCacheValid(cachedData)) {
      return cachedData;
    }

    // Fetch fresh data from NOAA
    const freshData = await fetchNOAAFlowData(riverId);
    if (freshData) {
      // Cache the fresh data
      await cacheFlowData(riverId, freshData);
      return freshData;
    }

    return null;
  } catch (error) {
    console.error(`❌ Error getting flow data for ${riverId}:`, error);
    return null;
  }
}

/**
 * Get cached flow data from Firestore
 */
async function getCachedFlowData(riverId) {
  try {
    const doc = await db.collection('flowForecastCache').doc(riverId).get();
    
    if (doc.exists) {
      const data = doc.data();
      return {
        ...data,
        lastUpdated: data.lastUpdated.toDate()
      };
    }
    return null;
  } catch (error) {
    console.error('❌ Error getting cached flow data:', error);
    return null;
  }
}

/**
 * Fetch fresh flow data from NOAA API
 */
async function fetchNOAAFlowData(riverId) {
  try {
    console.log(`🌐 Fetching NOAA data for river ${riverId}`);

    // Get NOAA reach ID mapping
    const noaaReachId = await getNoaaReachId(riverId);
    if (!noaaReachId) {
      console.warn(`⚠️ No NOAA reach ID mapping for river ${riverId}`);
      return null;
    }

    // Fetch short and medium range forecasts
    const [shortRange, mediumRange] = await Promise.allSettled([
      fetchNOAAShortRange(noaaReachId),
      fetchNOAAMediumRange(noaaReachId)
    ]);

    const shortRangeData = shortRange.status === 'fulfilled' ? shortRange.value : [];
    const mediumRangeData = mediumRange.status === 'fulfilled' ? mediumRange.value : [];

    if (shortRangeData.length > 0 || mediumRangeData.length > 0) {
      return {
        riverId,
        noaaReachId,
        shortRangeForecasts: shortRangeData,
        mediumRangeForecasts: mediumRangeData,
        lastUpdated: new Date()
      };
    }

    return null;
  } catch (error) {
    console.error('❌ Error fetching NOAA data:', error);
    return null;
  }
}

/**
 * Get NOAA reach ID for internal river ID
 * May need to map to COMID for return period API calls
 */
async function getNoaaReachId(riverId) {
  try {
    const doc = await db.collection('riverMappings').doc(riverId).get();
    
    if (doc.exists) {
      const mapping = doc.data();
      // Return NOAA reach ID for forecast API or COMID for return period API
      return mapping.noaaReachId || mapping.comid || mapping.reachId;
    }
    
    // Fallback: check if riverId is already a NOAA reach ID or COMID
    // NOAA reach IDs are typically 8-9 digits, COMIDs are similar
    if (/^\d{7,9}$/.test(riverId)) {
      return riverId;
    }
    
    // Try to extract NOAA ID from station collection
    const stationDoc = await db.collection('stations').doc(riverId).get();
    if (stationDoc.exists) {
      const stationData = stationDoc.data();
      return stationData.noaaReachId || stationData.comid || stationData.reachId || riverId;
    }
    
    console.warn(`⚠️ No NOAA reach ID mapping found for ${riverId}, using as-is`);
    return riverId;
  } catch (error) {
    console.warn(`⚠️ Error getting NOAA reach ID for ${riverId}:`, error);
    return riverId;
  }
}

/**
 * Fetch NOAA short range forecast (0-3 days)
 */
async function fetchNOAAShortRange(noaaReachId) {
  try {
    // Use real NOAA API: https://api.water.noaa.gov/nwps/v1/reaches/{reachId}/streamflow?series=short_range
    const url = `${config.forecastBaseUrl}/reaches/${noaaReachId}/streamflow?series=short_range`;
    
    console.log(`📡 Fetching short range forecast: ${url}`);
    
    const response = await axios.get(url, {
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Rivr-Notifications/1.0'
      }
    });
    
    if (response.status === 200 && response.data) {
      return parseNOAAForecastData(response.data, 'short');
    }
    
    return [];
  } catch (error) {
    console.warn('⚠️ Error fetching NOAA short range:', error.message);
    return [];
  }
}

/**
 * Fetch NOAA medium range forecast (4-10 days)
 */
async function fetchNOAAMediumRange(noaaReachId) {
  try {
    // Use real NOAA API: https://api.water.noaa.gov/nwps/v1/reaches/{reachId}/streamflow?series=medium_range
    const url = `${config.forecastBaseUrl}/reaches/${noaaReachId}/streamflow?series=medium_range`;
    
    console.log(`📡 Fetching medium range forecast: ${url}`);
    
    const response = await axios.get(url, {
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Rivr-Notifications/1.0'
      }
    });
    
    if (response.status === 200 && response.data) {
      return parseNOAAForecastData(response.data, 'medium');
    }
    
    return [];
  } catch (error) {
    console.warn('⚠️ Error fetching NOAA medium range:', error.message);
    return [];
  }
}

/**
 * Parse NOAA API response into forecast objects
 * Handles the real NOAA streamflow API response format
 */
function parseNOAAForecastData(data, range) {
  const forecasts = [];
  
  try {
    // Real NOAA API returns data in this structure:
    // { data: { streamflow: [{ time: "2024-01-01T00:00:00Z", value: 123.45 }, ...] } }
    
    const streamflowData = data?.data?.streamflow || data?.streamflow || [];
    
    for (const dataPoint of streamflowData) {
      if (dataPoint.value && dataPoint.time) {
        const flowValue = parseFloat(dataPoint.value);
        const validTime = new Date(dataPoint.time);
        
        // Only include future forecasts
        if (validTime > new Date() && !isNaN(flowValue)) {
          forecasts.push({
            flow: flowValue,
            unit: 'cfs', // NOAA streamflow API returns values in CFS
            validTime: validTime,
            range: range
          });
        }
      }
    }
    
    console.log(`📊 Parsed ${forecasts.length} ${range}-range forecasts`);
  } catch (error) {
    console.error('❌ Error parsing NOAA data:', error);
  }
  
  return forecasts;
}

/**
 * Get return period data for a river from Firestore cache
 * Uses cached data to avoid making API calls every time
 * 
 * Expected cached format based on API response:
 * [{"feature_id": 15039097, "return_period_2": 3518.03, "return_period_5": 6119.41, ...}]
 */
async function getReturnPeriodData(riverId) {
  try {
    // First try the return period cache
    const cacheDoc = await db.collection('returnPeriodCache').doc(riverId).get();
    
    if (cacheDoc.exists) {
      const cacheData = cacheDoc.data();
      
      // Check if cache is still valid (not older than 7 days)
      const lastUpdated = cacheData.lastUpdated || cacheData.timestamp;
      if (lastUpdated && isCacheValid(lastUpdated, 7 * 24 * 60 * 60 * 1000)) { // 7 days
        console.log(`📋 Using cached return period data for ${riverId}`);
        
        // Parse the cached return period data
        const periods = {};
        
        // Handle the exact API response format
        let returnPeriodRecord = null;
        
        if (Array.isArray(cacheData.data)) {
          // Direct API response format: [{"feature_id": 15039097, "return_period_2": 3518.03, ...}]
          returnPeriodRecord = cacheData.data[0];
        } else if (cacheData.data && Array.isArray(cacheData.data.data)) {
          // Nested format
          returnPeriodRecord = cacheData.data.data[0];
        } else if (cacheData.data && typeof cacheData.data === 'object') {
          // Single object format
          returnPeriodRecord = cacheData.data;
        } else if (cacheData.return_period_2) {
          // Direct fields in cache document
          returnPeriodRecord = cacheData;
        }
        
        if (returnPeriodRecord) {
          // Extract return periods using exact API field names
          if (returnPeriodRecord.return_period_2) periods[2] = parseFloat(returnPeriodRecord.return_period_2);
          if (returnPeriodRecord.return_period_5) periods[5] = parseFloat(returnPeriodRecord.return_period_5);
          if (returnPeriodRecord.return_period_10) periods[10] = parseFloat(returnPeriodRecord.return_period_10);
          if (returnPeriodRecord.return_period_25) periods[25] = parseFloat(returnPeriodRecord.return_period_25);
          if (returnPeriodRecord.return_period_50) periods[50] = parseFloat(returnPeriodRecord.return_period_50);
          if (returnPeriodRecord.return_period_100) periods[100] = parseFloat(returnPeriodRecord.return_period_100);
        }
        
        // Fallback: try alternative field naming patterns
        if (Object.keys(periods).length === 0) {
          // Try periods object format
          if (cacheData.periods) {
            Object.entries(cacheData.periods).forEach(([year, flow]) => {
              periods[parseInt(year)] = parseFloat(flow);
            });
          }
          
          // Try nested data.periods format
          if (cacheData.data && cacheData.data.periods) {
            Object.entries(cacheData.data.periods).forEach(([year, flow]) => {
              periods[parseInt(year)] = parseFloat(flow);
            });
          }
        }
        
        if (Object.keys(periods).length > 0) {
          return {
            riverId,
            periods,
            unit: cacheData.unit || 'cfs', // API returns values in CFS
            lastUpdated: lastUpdated.toDate ? lastUpdated.toDate() : new Date(lastUpdated)
          };
        }
      }
    }
    
    // Try alternative cache locations
    const returnPeriodDoc = await db.collection('returnPeriods').doc(riverId).get();
    if (returnPeriodDoc.exists) {
      const data = returnPeriodDoc.data();
      console.log(`📋 Using return period collection data for ${riverId}`);
      
      // Handle the same API format in this collection too
      const periods = {};
      
      if (data.return_period_2) periods[2] = parseFloat(data.return_period_2);
      if (data.return_period_5) periods[5] = parseFloat(data.return_period_5);
      if (data.return_period_10) periods[10] = parseFloat(data.return_period_10);
      if (data.return_period_25) periods[25] = parseFloat(data.return_period_25);
      if (data.return_period_50) periods[50] = parseFloat(data.return_period_50);
      if (data.return_period_100) periods[100] = parseFloat(data.return_period_100);
      
      // Fallback to periods object if direct fields not found
      if (Object.keys(periods).length === 0 && data.periods) {
        Object.entries(data.periods).forEach(([year, flow]) => {
          periods[parseInt(year)] = parseFloat(flow);
        });
      }
      
      return {
        riverId,
        periods,
        unit: data.unit || 'cfs',
        lastUpdated: data.lastUpdated ? data.lastUpdated.toDate() : new Date()
      };
    }
    
    console.warn(`⚠️ No cached return period data found for river ${riverId}`);
    return null;
  } catch (error) {
    console.error('❌ Error getting return period data:', error);
    return null;
  }
}

/**
 * Check if cached data is still valid
 */
function isCacheValid(timestamp, maxAgeMs) {
  const now = new Date();
  const cacheTime = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
  const age = now - cacheTime;
  return age < maxAgeMs;
}

/**
 * Get river name for alerts
 */
async function getRiverName(riverId) {
  try {
    // Try multiple collections to find river name
    const sources = ['stations', 'rivers', 'noaaFlowCache'];
    
    for (const collection of sources) {
      const doc = await db.collection(collection).doc(riverId).get();
      if (doc.exists) {
        const data = doc.data();
        const name = data.name || data.riverName || data.stationName;
        if (name) return name;
      }
    }
    
    return `River ${riverId}`;
  } catch (error) {
    return `River ${riverId}`;
  }
}

/**
 * Check forecasts against return periods and generate alerts
 */
function checkForecastsAgainstReturnPeriods(flowData, returnPeriods, userPreferences, riverName) {
  const alerts = [];
  
  try {
    // Check short range if enabled
    if (userPreferences.includeShortRange) {
      const shortAlerts = checkForecastsForRange(
        flowData.shortRangeForecasts,
        returnPeriods,
        userPreferences.userId,
        flowData.riverId,
        riverName,
        'short'
      );
      alerts.push(...shortAlerts);
    }

    // Check medium range if enabled
    if (userPreferences.includeMediumRange) {
      const mediumAlerts = checkForecastsForRange(
        flowData.mediumRangeForecasts,
        returnPeriods,
        userPreferences.userId,
        flowData.riverId,
        riverName,
        'medium'
      );
      alerts.push(...mediumAlerts);
    }
  } catch (error) {
    console.error('❌ Error checking forecasts:', error);
  }
  
  return alerts;
}

/**
 * Check forecasts for specific range against return periods
 */
function checkForecastsForRange(forecasts, returnPeriods, userId, riverId, riverName, range) {
  const alerts = [];
  
  // Sort return periods by flow value (descending) to check highest first
  const sortedPeriods = Object.entries(returnPeriods.periods || {})
    .map(([years, flow]) => ({ years: parseInt(years), flow: parseFloat(flow) }))
    .sort((a, b) => b.flow - a.flow);
  
  for (const forecast of forecasts) {
    // Check against return periods (highest first)
    for (const { years, flow: thresholdFlow } of sortedPeriods) {
      if (forecast.flow >= thresholdFlow) {
        const alertId = `${riverId}_${years}yr_${forecast.validTime.getTime()}`;
        
        alerts.push({
          alertId,
          userId,
          riverId,
          riverName,
          forecastedFlow: forecast.flow,
          flowUnit: forecast.unit,
          returnPeriod: years,
          returnPeriodFlow: thresholdFlow,
          forecastRange: range,
          forecastDateTime: forecast.validTime,
          alertTriggeredAt: new Date(),
          severity: getSeverityFromReturnPeriod(years)
        });
        
        // Only one alert per forecast (highest return period matched)
        break;
      }
    }
  }
  
  return alerts;
}

/**
 * Get alert severity from return period
 */
function getSeverityFromReturnPeriod(returnPeriod) {
  if (returnPeriod >= 50) return 'extreme';
  if (returnPeriod >= 25) return 'severe';
  if (returnPeriod >= 10) return 'major';
  if (returnPeriod >= 5) return 'significant';
  return 'moderate';
}

/**
 * Process an alert (check duplicates and send notification)
 */
async function processAlert(alert) {
  try {
    // Check for duplicates
    const isDuplicate = await isDuplicateAlert(alert);
    if (isDuplicate) {
      console.log(`ℹ️ Skipping duplicate alert: ${alert.alertId}`);
      return;
    }

    // Send FCM notification
    const success = await sendFCMNotification(alert);
    
    // Save to history
    await saveAlertToHistory({
      ...alert,
      sent: success,
      sentAt: success ? new Date() : null
    });
    
    console.log(`${success ? '✅' : '❌'} Alert processed: ${alert.riverName} - ${alert.severity}`);
    
  } catch (error) {
    console.error('❌ Error processing alert:', error);
  }
}

/**
 * Check if alert is duplicate of recent alerts
 */
async function isDuplicateAlert(alert) {
  try {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const existingAlerts = await db
      .collection('flowAlertHistory')
      .where('userId', '==', alert.userId)
      .where('riverId', '==', alert.riverId)
      .where('returnPeriod', '==', alert.returnPeriod)
      .where('alertTriggeredAt', '>=', twentyFourHoursAgo)
      .get();

    return !existingAlerts.empty;
  } catch (error) {
    console.error('❌ Error checking duplicates:', error);
    return false;
  }
}

/**
 * Send FCM notification for alert
 */
async function sendFCMNotification(alert) {
  try {
    // Get user's FCM token
    const userToken = await getUserFCMToken(alert.userId);
    if (!userToken) {
      console.warn(`⚠️ No FCM token for user ${alert.userId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: `${getSeverityDisplayName(alert.severity)} Flow Alert: ${alert.riverName}`,
        body: formatNotificationBody(alert)
      },
      data: {
        type: 'flow_alert',
        riverId: alert.riverId,
        riverName: alert.riverName,
        severity: alert.severity,
        returnPeriod: alert.returnPeriod.toString(),
        alertId: alert.alertId
      },
      android: {
        priority: 'high',
        notification: {
          color: getSeverityColor(alert.severity),
          priority: getSeverityNotificationPriority(alert.severity)
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    };

    await admin.messaging().send(message);
    return true;
  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    return false;
  }
}

/**
 * Get user's FCM token
 */
async function getUserFCMToken(userId) {
  try {
    const doc = await db.collection('fcmTokens').doc(userId).get();
    return doc.exists ? doc.data().token : null;
  } catch (error) {
    console.error('❌ Error getting FCM token:', error);
    return null;
  }
}

/**
 * Format notification body
 */
function formatNotificationBody(alert) {
  const flowFormatted = Math.round(alert.forecastedFlow);
  const returnFlowFormatted = Math.round(alert.returnPeriodFlow);
  const dateFormatted = formatForecastDate(alert.forecastDateTime);
  
  return `Forecasted flow: ${flowFormatted} ${alert.flowUnit} (${dateFormatted})\n` +
         `Matches ${alert.returnPeriod}-year return period (${returnFlowFormatted} ${alert.flowUnit})`;
}

/**
 * Format forecast date for notification
 */
function formatForecastDate(date) {
  const now = new Date();
  const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));
  
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Tomorrow';
  if (diffDays <= 7) return `In ${diffDays} days`;
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

/**
 * Get severity display name
 */
function getSeverityDisplayName(severity) {
  const names = {
    moderate: 'Moderate',
    significant: 'Significant',
    major: 'Major',
    severe: 'Severe',
    extreme: 'Extreme'
  };
  return names[severity] || 'Alert';
}

/**
 * Get severity color for notifications
 */
function getSeverityColor(severity) {
  const colors = {
    moderate: '#2196F3',
    significant: '#FF9800',
    major: '#FF5722',
    severe: '#F44336',
    extreme: '#9C27B0'
  };
  return colors[severity] || '#2196F3';
}

/**
 * Get severity notification priority
 */
function getSeverityNotificationPriority(severity) {
  return ['severe', 'extreme'].includes(severity) ? 'high' : 'default';
}

/**
 * Save alert to history
 */
async function saveAlertToHistory(alert) {
  try {
    await db.collection('flowAlertHistory').doc(alert.alertId).set({
      ...alert,
      alertTriggeredAt: admin.firestore.Timestamp.fromDate(alert.alertTriggeredAt),
      forecastDateTime: admin.firestore.Timestamp.fromDate(alert.forecastDateTime),
      sentAt: alert.sentAt ? admin.firestore.Timestamp.fromDate(alert.sentAt) : null
    });
  } catch (error) {
    console.error('❌ Error saving alert history:', error);
  }
}

/**
 * Cache flow data
 */
async function cacheFlowData(riverId, data) {
  try {
    await db.collection('flowForecastCache').doc(riverId).set({
      ...data,
      lastUpdated: admin.firestore.Timestamp.fromDate(data.lastUpdated)
    });
  } catch (error) {
    console.error('❌ Error caching flow data:', error);
  }
}

/**
 * Check if cached data is still valid
 */
function isCacheValid(cachedData) {
  const now = new Date();
  const age = now - cachedData.lastUpdated;
  
  // Cache valid for 30 minutes
  return age < 30 * 60 * 1000;
}

/**
 * Environment configuration
 * Set these in Firebase Functions environment:
 * firebase functions:config:set forecast.base_url="https://api.water.noaa.gov/nwps/v1"
 * firebase functions:config:set return_period.base_url="https://nwm-api-updt-9f6idmxh.uc.gateway.dev"
 * firebase functions:config:set api.key="AIzaSyArCbLaEevrqrVPJDzu2OioM_kNmCBtsx8"
 */
const config = {
  forecastBaseUrl: process.env.FORECAST_BASE_URL || functions.config()?.forecast?.base_url || 'https://api.water.noaa.gov/nwps/v1',
  returnPeriodBaseUrl: process.env.RETURN_BASE_URL || functions.config()?.return_period?.base_url || 'https://nwm-api-updt-9f6idmxh.uc.gateway.dev',
  apiKey: process.env.API_KEY || functions.config()?.api?.key || ''
};