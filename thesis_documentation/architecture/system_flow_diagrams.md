# System Flow Diagrams for Thesis Documentation

## Overview of System Flow Diagrams

This document provides comprehensive flow diagrams for the Rivr notification system, designed to support thesis documentation and demonstrate the complete system architecture, data flows, and user interactions.

## 1. High-Level System Architecture Flow

```mermaid
graph TB
    subgraph "External Data Sources"
        NOAA[NOAA National Water Model API]
        CIROH[CIROH Return Periods API]
    end
    
    subgraph "Firebase Cloud Infrastructure"
        CF[Cloud Functions]
        FS[Firestore Database]
        FCM[Firebase Cloud Messaging]
        AUTH[Firebase Authentication]
    end
    
    subgraph "Mobile Application"
        APP[Flutter App]
        NOTIF[Notification Handler]
        UI[User Interface]
    end
    
    subgraph "User Devices"
        iOS[iOS Device]
        ANDROID[Android Device]
    end
    
    NOAA --> CF
    USGS --> CF
    CF --> FS
    CF --> FCM
    FS --> APP
    FCM --> NOTIF
    AUTH --> APP
    APP --> UI
    NOTIF --> iOS
    NOTIF --> ANDROID
    
    classDef external fill:#e1f5fe
    classDef firebase fill:#fff3e0
    classDef mobile fill:#e8f5e8
    classDef device fill:#fce4ec
    
    class NOAA,USGS external
    class CF,FS,FCM,AUTH firebase
    class APP,NOTIF,UI mobile
    class iOS,ANDROID device
```

## 2. Data Ingestion and Processing Flow

```mermaid
sequenceDiagram
    participant Schedule as Cloud Scheduler
    participant NOAA as NOAA API
    participant CF as Cloud Functions
    participant Cache as Firestore Cache
    participant Threshold as Threshold Processor
    participant FCM as FCM Service
    participant App as Mobile App
    
    Schedule->>CF: Trigger every 30 minutes
    CF->>NOAA: Fetch flow data for monitored reaches
    NOAA-->>CF: Return flow data (JSON)
    CF->>CF: Transform NOAA data to Rivr format
    CF->>Cache: Update flow data cache
    CF->>Threshold: Trigger threshold evaluation
    
    Threshold->>Cache: Query user thresholds
    Cache-->>Threshold: Return threshold configurations
    Threshold->>Threshold: Evaluate alerts
    
    alt Threshold Exceeded
        Threshold->>FCM: Generate notification
        FCM->>App: Deliver push notification
        App->>App: Display notification to user
    end
    
    Threshold->>Cache: Log notification history
```

## 3. User Onboarding and Setup Flow

```mermaid
flowchart TD
    START([User Opens App]) --> AUTH_CHECK{Authenticated?}
    
    AUTH_CHECK -->|No| LOGIN[Login/Register]
    AUTH_CHECK -->|Yes| PERM_CHECK{Notification Permissions?}
    
    LOGIN --> PERM_CHECK
    
    PERM_CHECK -->|No| REQUEST_PERM[Request Notification Permissions]
    PERM_CHECK -->|Yes| ONBOARD_CHECK{First Time User?}
    
    REQUEST_PERM --> PERM_RESULT{Permission Granted?}
    PERM_RESULT -->|No| EXPLAIN[Explain Benefits & Re-ask]
    PERM_RESULT -->|Yes| ONBOARD_CHECK
    EXPLAIN --> PERM_RESULT
    
    ONBOARD_CHECK -->|Yes| INTRO[Show Notification Features]
    ONBOARD_CHECK -->|No| MAIN_APP[Main App Interface]
    
    INTRO --> SETUP_GUIDE[Guided Threshold Setup]
    SETUP_GUIDE --> SELECT_STATIONS[Select Favorite Stations]
    SELECT_STATIONS --> SET_ACTIVITIES[Choose Activities]
    SET_ACTIVITIES --> SET_THRESHOLDS[Configure Flow Thresholds]
    SET_THRESHOLDS --> CONFIRM_SETTINGS[Review & Confirm]
    CONFIRM_SETTINGS --> SAVE_PREFS[Save to Firestore]
    SAVE_PREFS --> MAIN_APP
    
    MAIN_APP --> END([Ready to Receive Notifications])
    
    classDef decision fill:#fff2cc
    classDef process fill:#d5e8d4
    classDef start fill:#f8cecc
    
    class AUTH_CHECK,PERM_CHECK,PERM_RESULT,ONBOARD_CHECK decision
    class LOGIN,REQUEST_PERM,INTRO,SETUP_GUIDE,SELECT_STATIONS,SET_ACTIVITIES,SET_THRESHOLDS,CONFIRM_SETTINGS,SAVE_PREFS,MAIN_APP,EXPLAIN process
    class START,END start
```

## 4. Threshold Creation and Management Flow

```mermaid
flowchart LR
    subgraph "User Interface"
        SETTINGS[Settings Screen]
        THRESHOLD_LIST[Threshold List]
        CREATE_FORM[Create Threshold Form]
        EDIT_FORM[Edit Threshold Form]
    end
    
    subgraph "Form Components"
        STATION_SELECT[Station Selection]
        ACTIVITY_SELECT[Activity Type]
        VALUE_INPUT[Threshold Value]
        TYPE_SELECT[Alert Type]
        PREVIEW[Preview Message]
    end
    
    subgraph "Backend Processing"
        VALIDATE[Validation]
        FIRESTORE[Save to Firestore]
        UPDATE_SUBS[Update Cloud Function Subscriptions]
    end
    
    subgraph "Confirmation"
        SUCCESS[Success Message]
        TEST_NOTIF[Send Test Notification]
    end
    
    SETTINGS --> THRESHOLD_LIST
    THRESHOLD_LIST --> CREATE_FORM
    THRESHOLD_LIST --> EDIT_FORM
    
    CREATE_FORM --> STATION_SELECT
    STATION_SELECT --> ACTIVITY_SELECT
    ACTIVITY_SELECT --> VALUE_INPUT
    VALUE_INPUT --> TYPE_SELECT
    TYPE_SELECT --> PREVIEW
    
    PREVIEW --> VALIDATE
    VALIDATE --> FIRESTORE
    FIRESTORE --> UPDATE_SUBS
    UPDATE_SUBS --> SUCCESS
    SUCCESS --> TEST_NOTIF
    
    EDIT_FORM --> STATION_SELECT
```

## 5. Real-time Notification Delivery Flow

```mermaid
sequenceDiagram
    participant CF as Cloud Functions
    participant TP as Threshold Processor
    participant MG as Message Generator
    participant FCM as FCM Service
    participant Device as User Device
    participant App as Rivr App
    participant User as User
    
    Note over CF: New flow data received
    CF->>TP: Evaluate user thresholds
    TP->>TP: Check threshold conditions
    
    alt Threshold Exceeded
        TP->>MG: Generate alert message
        MG->>MG: Select activity-specific template
        MG->>MG: Populate with current data
        MG-->>TP: Return formatted message
        
        TP->>FCM: Send notification request
        FCM->>Device: Deliver push notification
        
        Device->>App: Handle notification received
        App->>App: Process notification content
        App->>User: Display notification
        
        alt User Taps Notification
            User->>App: Tap notification
            App->>App: Deep link to station details
            App->>CF: Log user engagement
        end
        
        alt User Dismisses
            User->>App: Dismiss notification
            App->>CF: Log dismissal
        end
    end
```

## 6. Error Handling and Fallback Flow

```mermaid
flowchart TD
    API_CALL[NOAA API Call] --> API_SUCCESS{API Success?}
    
    API_SUCCESS -->|Yes| PROCESS_DATA[Process & Cache Data]
    API_SUCCESS -->|No| CHECK_CACHE{Cache Available?}
    
    CHECK_CACHE -->|Yes| USE_CACHE[Use Cached Data]
    CHECK_CACHE -->|No| TRY_BACKUP[Try USGS Backup API]
    
    TRY_BACKUP --> BACKUP_SUCCESS{Backup Success?}
    BACKUP_SUCCESS -->|Yes| PROCESS_BACKUP[Process Backup Data]
    BACKUP_SUCCESS -->|No| LOG_ERROR[Log Error & Alert Admin]
    
    PROCESS_DATA --> THRESHOLD_CHECK[Check Thresholds]
    USE_CACHE --> THRESHOLD_CHECK
    PROCESS_BACKUP --> THRESHOLD_CHECK
    
    THRESHOLD_CHECK --> SEND_NOTIF{Send Notifications?}
    SEND_NOTIF -->|Yes| FCM_SEND[Send via FCM]
    SEND_NOTIF -->|No| COMPLETE[Complete Processing]
    
    FCM_SEND --> FCM_SUCCESS{FCM Success?}
    FCM_SUCCESS -->|Yes| LOG_SUCCESS[Log Delivery Success]
    FCM_SUCCESS -->|No| RETRY[Retry with Exponential Backoff]
    
    RETRY --> RETRY_SUCCESS{Retry Success?}
    RETRY_SUCCESS -->|Yes| LOG_SUCCESS
    RETRY_SUCCESS -->|No| LOG_FAILURE[Log Delivery Failure]
    
    LOG_ERROR --> COMPLETE
    LOG_SUCCESS --> COMPLETE
    LOG_FAILURE --> COMPLETE
    
    classDef error fill:#ffcccc
    classDef success fill:#ccffcc
    classDef process fill:#cce5ff
    
    class API_CALL,PROCESS_DATA,PROCESS_BACKUP,THRESHOLD_CHECK,FCM_SEND,RETRY process
    class LOG_SUCCESS success
    class LOG_ERROR,LOG_FAILURE error
```

## 7. User Interaction and Engagement Flow

```mermaid
journey
    title User Journey with Notification System
    section Initial Setup
      Install App: 5: User
      Grant Permissions: 4: User
      Setup Thresholds: 3: User, System
      Receive First Alert: 5: User, System
    section Daily Usage
      Check Flow Conditions: 3: User
      Receive Activity Alert: 5: User, System
      Plan Water Activity: 5: User
      Use App for Details: 4: User
    section Emergency Scenario
      Dangerous Conditions: 1: Environment
      Receive Safety Alert: 5: User, System
      Cancel Activity: 5: User
      Share with Friends: 4: User
    section Long-term Engagement
      Adjust Thresholds: 4: User
      Explore New Stations: 4: User
      Provide Feedback: 3: User, Researcher
```

## 8. Data Privacy and Security Flow

```mermaid
flowchart LR
    subgraph "Data Collection"
        USER_INPUT[User Input]
        SYSTEM_LOGS[System Logs]
        USAGE_DATA[Usage Analytics]
    end
    
    subgraph "Privacy Processing"
        ANONYMIZE[Anonymize PII]
        ENCRYPT[Encrypt Data]
        VALIDATE[Validate Permissions]
    end
    
    subgraph "Storage"
        FIRESTORE_SECURE[Encrypted Firestore]
        USER_CONSENT[Consent Records]
        AUDIT_LOG[Audit Trail]
    end
    
    subgraph "Access Control"
        AUTH_CHECK[Authentication Check]
        PERMISSION_CHECK[Permission Validation]
        RATE_LIMIT[Rate Limiting]
    end
    
    subgraph "Data Use"
        RESEARCH_ANALYSIS[Research Analysis]
        SYSTEM_IMPROVEMENT[System Optimization]
        THESIS_DOCUMENTATION[Thesis Documentation]
    end
    
    USER_INPUT --> ANONYMIZE
    SYSTEM_LOGS --> ENCRYPT
    USAGE_DATA --> VALIDATE
    
    ANONYMIZE --> FIRESTORE_SECURE
    ENCRYPT --> USER_CONSENT
    VALIDATE --> AUDIT_LOG
    
    FIRESTORE_SECURE --> AUTH_CHECK
    USER_CONSENT --> PERMISSION_CHECK
    AUDIT_LOG --> RATE_LIMIT
    
    AUTH_CHECK --> RESEARCH_ANALYSIS
    PERMISSION_CHECK --> SYSTEM_IMPROVEMENT
    RATE_LIMIT --> THESIS_DOCUMENTATION
```

## 9. Performance Monitoring Flow

```mermaid
flowchart TB
    subgraph "System Components"
        NOAA_API[NOAA API]
        CLOUD_FUNC[Cloud Functions]
        FIRESTORE[Firestore]
        FCM[FCM Service]
        MOBILE_APP[Mobile App]
    end
    
    subgraph "Metrics Collection"
        API_METRICS[API Response Times]
        FUNC_METRICS[Function Execution Times]
        DB_METRICS[Database Query Performance]
        NOTIF_METRICS[Notification Delivery Rates]
        USER_METRICS[User Engagement Metrics]
    end
    
    subgraph "Analysis & Alerting"
        DASHBOARD[Performance Dashboard]
        ALERTS[Automated Alerts]
        REPORTS[Thesis Reports]
    end
    
    NOAA_API --> API_METRICS
    CLOUD_FUNC --> FUNC_METRICS
    FIRESTORE --> DB_METRICS
    FCM --> NOTIF_METRICS
    MOBILE_APP --> USER_METRICS
    
    API_METRICS --> DASHBOARD
    FUNC_METRICS --> DASHBOARD
    DB_METRICS --> ALERTS
    NOTIF_METRICS --> REPORTS
    USER_METRICS --> REPORTS
    
    DASHBOARD --> ALERTS
    ALERTS --> REPORTS
```

## 10. Thesis Research Data Flow

```mermaid
flowchart LR
    subgraph "Data Sources"
        USER_BEHAVIOR[User Behavior]
        SYSTEM_PERFORMANCE[System Performance]
        SURVEY_RESPONSES[Survey Responses]
        INTERVIEW_DATA[Interview Data]
    end
    
    subgraph "Data Processing"
        ANONYMIZATION[Data Anonymization]
        AGGREGATION[Statistical Aggregation]
        ANALYSIS[Quantitative Analysis]
        CODING[Qualitative Coding]
    end
    
    subgraph "Research Outputs"
        METRICS[Performance Metrics]
        INSIGHTS[User Insights]
        RECOMMENDATIONS[Design Recommendations]
        THESIS_DOC[Thesis Documentation]
    end
    
    USER_BEHAVIOR --> ANONYMIZATION
    SYSTEM_PERFORMANCE --> AGGREGATION
    SURVEY_RESPONSES --> ANALYSIS
    INTERVIEW_DATA --> CODING
    
    ANONYMIZATION --> METRICS
    AGGREGATION --> INSIGHTS
    ANALYSIS --> RECOMMENDATIONS
    CODING --> THESIS_DOC
    
    METRICS --> THESIS_DOC
    INSIGHTS --> THESIS_DOC
    RECOMMENDATIONS --> THESIS_DOC
```

## Flow Diagram Usage in Thesis

### Architecture Documentation
- Use diagrams 1, 2, and 8 to explain system architecture in methodology section
- Include diagrams 6 and 9 to demonstrate reliability and error handling

### User Experience Analysis
- Diagram 3 and 7 for user onboarding and engagement analysis
- Diagram 4 for threshold configuration usability studies

### Technical Implementation
- Diagrams 2, 5, and 6 for detailed technical implementation discussion
- Use for troubleshooting and system validation

### Research Methodology
- Diagram 10 for explaining data collection and analysis procedures
- Diagram 8 for privacy and ethical considerations

### Results Presentation
- Performance metrics visualization using diagram 9 patterns
- User journey analysis using diagram 7 framework

These flow diagrams provide comprehensive visual documentation of the notification system architecture, supporting both technical implementation and academic thesis requirements.