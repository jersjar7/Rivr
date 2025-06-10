# Current Rivr Architecture Integration Points

## Existing Rivr System Architecture

### Technology Stack Overview
- **Frontend**: Flutter mobile application (iOS & Android)
- **Backend**: Firebase ecosystem (project: rivr-official)
- **Database**: Cloud Firestore (NoSQL document database)
- **Authentication**: Firebase Authentication
- **Hosting**: Firebase Hosting (for any web components)
- **Analytics**: Firebase Analytics (basic usage tracking)

### Current Firebase Project Structure

#### Firebase Services Currently Enabled
```
rivr-official (Firebase Project)
├── Authentication
│   ├── Email/Password providers
│   ├── Anonymous authentication
│   └── User management
├── Cloud Firestore
│   ├── Users collection
│   ├── Stations collection
│   ├── Favorites collection
│   └── FlowData collection
├── Firebase Hosting
│   └── Static web assets
└── Analytics
    └── Basic user engagement metrics
```

#### Current Firestore Data Model
```javascript
// Users Collection
users/{userId} {
  email: string,
  displayName: string,
  createdAt: timestamp,
  preferences: {
    units: "CFS" | "CMS",
    theme: "light" | "dark",
    language: string
  }
}

// Stations Collection  
stations/{stationId} {
  name: string,
  location: {
    latitude: number,
    longitude: number,
    state: string,
    region: string
  },
  source: string, // Current data source
  lastUpdated: timestamp,
  status: "active" | "inactive"
}

// Favorites Collection
favorites/{userId}/stations/{stationId} {
  addedAt: timestamp,
  customName?: string,
  notes?: string
}

// FlowData Collection
flowData/{stationId}/readings/{timestamp} {
  flow: number,
  unit: "CFS" | "CMS",
  timestamp: timestamp,
  source: string,
  quality: "good" | "fair" | "poor"
}
```

### Current Flutter Application Architecture

#### Project Structure
```
lib/
├── main.dart
├── core/
│   ├── constants/
│   ├── utils/
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── flow_data_service.dart
│   └── models/
│       ├── user_model.dart
│       ├── station_model.dart
│       └── flow_data_model.dart
├── features/
│   ├── authentication/
│   ├── stations/
│   ├── favorites/
│   ├── flow_display/
│   └── settings/
└── shared/
    ├── widgets/
    ├── themes/
    └── navigation/
```

#### Key Service Classes (Current)
```dart
// AuthService - User authentication management
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Future<UserCredential> signIn(String email, String password);
  Future<void> signOut();
  Future<UserCredential> createAccount(String email, String password);
}

// FirestoreService - Database operations
class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  
  Future<void> saveUserData(UserModel user);
  Stream<List<StationModel>> getUserStations(String userId);
  Future<void> addToFavorites(String userId, String stationId);
}

// FlowDataService - Current flow data management
class FlowDataService {
  Future<FlowData> getCurrentFlow(String stationId);
  Future<List<FlowData>> getFlowForecast(String stationId);
  Stream<FlowData> getRealtimeFlow(String stationId);
}
```

## Integration Points for Notification System

### 1. Firebase Authentication Integration
**Current State**: Robust user authentication system
**Integration Approach**: Extend existing auth to support notification preferences

```dart
// Enhanced User Model for Notifications
class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final UserPreferences preferences;
  final NotificationSettings notificationSettings; // NEW
  
  // Existing fields...
}

class NotificationSettings {
  final bool emergencyAlerts;
  final bool activityAlerts;
  final String frequency; // 'realtime', 'daily', 'weekly'
  final List<String> quietHours;
  final bool enabled;
}
```

### 2. Firestore Database Integration
**Current State**: Well-structured document database
**Integration Approach**: Add new collections while maintaining existing structure

```javascript
// New Collections for Notification System
notificationPreferences/{userId} {
  emergencyAlerts: boolean,
  activityAlerts: boolean,
  frequency: string,
  quietHours: array,
  lastUpdated: timestamp
}

userThresholds/{userId}/thresholds/{thresholdId} {
  stationId: string,
  alertType: "above" | "below" | "range",
  value: number,
  unit: string,
  activity: string, // "fishing", "kayaking", etc.
  enabled: boolean,
  createdAt: timestamp
}

notificationHistory/{userId}/notifications/{notificationId} {
  title: string,
  body: string,
  type: "safety" | "activity" | "information",
  stationId: string,
  sentAt: timestamp,
  opened: boolean,
  actionTaken: boolean
}

noaaFlowCache/{stationId} {
  currentFlow: number,
  forecast: array,
  lastUpdated: timestamp,
  source: "NOAA_NWM"
}
```

### 3. Current Flow Data Service Integration
**Current State**: Basic flow data fetching and display
**Integration Approach**: Extend to support NOAA integration and threshold monitoring

```dart
// Enhanced FlowDataService
class FlowDataService {
  // Existing methods...
  
  // New methods for notification system
  Future<List<FlowData>> fetchNOAAData(List<String> stationIds);
  Future<void> cacheFlowData(List<FlowData> data);
  Future<List<ThresholdAlert>> checkUserThresholds(String userId);
  Stream<FlowData> monitorStationForUser(String userId, String stationId);
}
```

### 4. Navigation and UI Integration
**Current State**: Drawer-based navigation with feature screens
**Integration Approach**: Add notification settings to existing navigation structure

```dart
// Enhanced Navigation Structure
class AppNavigation {
  static const Map<String, String> routes = {
    // Existing routes...
    '/settings': 'Settings',
    '/settings/notifications': 'Notification Settings', // NEW
    '/notifications/history': 'Notification History',   // NEW
    '/stations/threshold-setup': 'Alert Setup',         // NEW
  };
}
```

## Technical Integration Strategy

### Phase 1: Foundation Extensions
1. **Database Schema Extension**
   - Add new Firestore collections for notifications
   - Extend existing user model with notification preferences
   - Create indexes for efficient notification queries

2. **Authentication Service Extension**
   - Extend user profile to include notification settings
   - Add device token management for push notifications
   - Implement notification permission handling

### Phase 2: Service Layer Integration
1. **Enhanced Data Services**
   - Extend FlowDataService to support NOAA API integration
   - Add NotificationService for managing alerts
   - Create ThresholdService for user-defined triggers

2. **Background Processing Setup**
   - Firebase Cloud Functions for scheduled monitoring
   - FCM integration for push notification delivery
   - Error handling and retry mechanisms

### Phase 3: UI/UX Integration
1. **Settings Integration**
   - Add notification preferences to existing settings screen
   - Create threshold management interface
   - Integrate with existing favorites system

2. **Notification Handling**
   - Foreground notification display
   - Background notification processing
   - Deep linking to relevant app sections

## Compatibility Considerations

### Maintaining Existing Functionality
- **Zero Breaking Changes**: All existing features continue to work
- **Backward Compatibility**: Existing user data remains valid
- **Performance Impact**: Minimize impact on current app performance
- **User Experience**: Enhance without disrupting current workflows

### Data Migration Strategy
```dart
// User data migration for notification features
class UserMigrationService {
  Future<void> migrateUserToNotifications(String userId) {
    // Create default notification settings
    // Preserve existing user preferences  
    // Initialize with sensible defaults
  }
}
```

### Firestore Security Rules Updates
```javascript
// Enhanced security rules for new collections
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Existing rules...
    
    // New notification-specific rules
    match /notificationPreferences/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /userThresholds/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /notificationHistory/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Performance Integration Points

### Efficient Data Access
- **Firestore Indexes**: Optimize queries for notification processing
- **Data Caching**: Reduce API calls through intelligent caching
- **Batch Operations**: Group database operations for efficiency

### Background Processing Optimization
- **Scheduled Functions**: Efficient Cloud Function scheduling
- **API Rate Limiting**: Respect NOAA API constraints
- **Resource Management**: Monitor Cloud Function execution costs

### Mobile App Performance
- **Minimal Battery Impact**: Efficient notification handling
- **Network Optimization**: Reduce unnecessary data transfer
- **UI Responsiveness**: Maintain smooth user experience

## Integration Testing Strategy

### Database Integration Tests
```dart
// Test existing functionality with new schema
testWidgets('User favorites still work after notification integration', (tester) async {
  // Verify existing favorites functionality
  // Test with new database schema
});

testWidgets('Flow data display unaffected by notification features', (tester) async {
  // Test core flow display functionality
  // Ensure no performance degradation
});
```

### API Integration Tests
```dart
// Test backward compatibility
test('Existing flow data API still functions', () async {
  // Verify current API endpoints still work
  // Test data format compatibility
});
```

### End-to-End Integration Tests
```dart
// Test complete user workflows
testWidgets('Complete user journey with notifications', (tester) async {
  // Login -> Setup notifications -> Receive alerts -> View data
  // Verify entire flow works seamlessly
});
```

## Migration and Deployment Strategy

### Gradual Feature Rollout
1. **Database Schema Updates**: Deploy new collections without breaking existing code
2. **Backend Services**: Add Cloud Functions while maintaining current functionality  
3. **Mobile App Updates**: Feature flags for gradual notification rollout
4. **User Migration**: Automatic setup of notification defaults for existing users

### Rollback Capability
- **Feature Toggles**: Ability to disable notification features
- **Data Preservation**: Maintain existing data integrity
- **Service Isolation**: Notification failures don't affect core app

This integration strategy ensures the notification system enhances the existing Rivr application while maintaining all current functionality and providing a smooth user experience.
