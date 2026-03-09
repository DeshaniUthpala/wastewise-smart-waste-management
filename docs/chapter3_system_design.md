# CHAPTER 3: SYSTEM DESIGN

## Introduction

System design serves as a critical phase in the development of the "WasteApp" application, transforming the identified requirements into structured technical solutions. This chapter outlines the architecture and detailed design of the proposed smart waste management system, ensuring that the functionalities align with the project objectives. Key components of this chapter include the class diagram, which illustrates the system's object structure, interface design showcasing user interaction, data design detailing the organization of data elements, and modular design that represents the logical breakdown of the system's functionality. These elements collectively ensure the scalability, efficiency, and usability of the application.

---

## Class Diagram

The class diagram below represents the object-oriented structure of the WasteApp system, showing the relationships between different entities and their attributes.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLASS DIAGRAM                                   │
│                         WasteApp System Design                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐
│        <<abstract>>         │
│         UserModel           │
├─────────────────────────────┤
│ - uid: String               │
│ - name: String              │
│ - email: String             │
│ - phone: String?            │
│ - role: String              │
│ - profileImageUrl: String?  │
│ - createdAt: DateTime       │
│ - lastLogin: DateTime?      │
│ - isActive: bool            │
├─────────────────────────────┤
│ + toMap(): Map              │
│ + fromMap(): UserModel      │
│ + copyWith(): UserModel     │
└─────────────┬───────────────┘
              │
      ┌───────┴───────┬───────────────┐
      │               │               │
      ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ CitizenModel│ │ DriverModel │ │ AdminModel  │
├─────────────┤ ├─────────────┤ ├─────────────┤
│- address    │ │- vehicleId  │ │(inherits    │
│- location   │ │- vehicleNo  │ │ UserModel)  │
│- rewardPts  │ │- vehicleType│ │             │
│- wastePref  │ │- licenseNo  │ │             │
│             │ │- isAvailable│ │             │
│             │ │- currentLoc │ │             │
│             │ │- rating     │ │             │
│             │ │- completedPU│ │             │
└──────┬──────┘ └──────┬──────┘ └─────────────┘
       │               │
       │ 1..*          │ 1..*
       ▼               ▼
┌─────────────────────────────┐     ┌─────────────────────────────┐
│     PickupRequestModel      │     │        RouteModel           │
├─────────────────────────────┤     ├─────────────────────────────┤
│ - id: String?               │     │ - id: String?               │
│ - citizenId: String         │◄────│ - name: String              │
│ - driverId: String?         │     │ - driverId: String?         │
│ - location: LocationModel   │     │ - waypoints: List<Location> │
│ - wasteType: String         │     │ - pickupRequestIds: List    │
│ - wasteCategory: String?    │     │ - status: String            │
│ - estimatedWeight: double?  │     │ - startTime: DateTime?      │
│ - status: String            │     │ - endTime: DateTime?        │
│ - requestedDate: DateTime   │     │ - totalDistance: double?    │
│ - scheduledDate: DateTime?  │     │ - estimatedDuration: int?   │
│ - completedDate: DateTime?  │     │ - createdAt: DateTime       │
│ - specialInstructions: Str? │     ├─────────────────────────────┤
│ - imageUrls: List<String>?  │     │ + toMap(): Map              │
│ - rating: double?           │     │ + fromMap(): RouteModel     │
├─────────────────────────────┤     └─────────────────────────────┘
│ + toMap(): Map              │
│ + fromMap(): PickupRequest  │
│ + copyWith(): PickupRequest │
└─────────────────────────────┘

┌─────────────────────────────┐     ┌─────────────────────────────┐
│       ScheduleModel         │     │       ReportModel           │
├─────────────────────────────┤     ├─────────────────────────────┤
│ - id: String?               │     │ - id: String?               │
│ - area: String              │     │ - reporterId: String        │
│ - wasteType: String         │     │ - title: String             │
│ - daysOfWeek: List<String>  │     │ - description: String       │
│ - collectionTime: String    │     │ - type: String              │
│ - driverId: String?         │     │ - priority: String          │
│ - routeId: String?          │     │ - status: String            │
│ - isActive: bool            │     │ - location: LocationModel?  │
│ - createdAt: DateTime       │     │ - imageUrls: List<String>?  │
│ - lastUpdated: DateTime?    │     │ - createdAt: DateTime       │
│ - location: LocationModel?  │     │ - resolvedAt: DateTime?     │
│ - description: String?      │     │ - assignedTo: String?       │
│ - isCommon: bool            │     │ - resolutionNotes: String?  │
│ - citizenId: String?        │     ├─────────────────────────────┤
│ - pickupRequestId: String?  │     │ + toMap(): Map              │
├─────────────────────────────┤     │ + fromMap(): ReportModel    │
│ + toMap(): Map              │     │ + copyWith(): ReportModel   │
│ + fromMap(): ScheduleModel  │     └─────────────────────────────┘
│ + copyWith(): ScheduleModel │
└─────────────────────────────┘

┌─────────────────────────────┐     ┌─────────────────────────────┐
│     NotificationModel       │     │       LocationModel         │
├─────────────────────────────┤     ├─────────────────────────────┤
│ - id: String?               │     │ - latitude: double          │
│ - userId: String            │     │ - longitude: double         │
│ - title: String             │     │ - address: String?          │
│ - message: String           │     │ - city: String?             │
│ - type: String              │     │ - postalCode: String?       │
│ - relatedEntityId: String?  │     ├─────────────────────────────┤
│ - relatedEntityType: String?│     │ + toMap(): Map              │
│ - isRead: bool              │     │ + fromMap(): LocationModel  │
│ - createdAt: DateTime       │     └─────────────────────────────┘
│ - readAt: DateTime?         │
│ - metadata: Map?            │     ┌─────────────────────────────┐
├─────────────────────────────┤     │      WasteTypeModel         │
│ + toMap(): Map              │     ├─────────────────────────────┤
│ + fromMap(): Notification   │     │ - id: String?               │
│ + copyWith(): Notification  │     │ - name: String              │
└─────────────────────────────┘     │ - category: String          │
                                    │ - description: String?      │
┌─────────────────────────────┐     │ - iconUrl: String?          │
│      StatisticsModel        │     │ - color: String?            │
├─────────────────────────────┤     │ - isRecyclable: bool        │
│ - id: String?               │     │ - disposalInstructions:List │
│ - date: DateTime            │     ├─────────────────────────────┤
│ - totalPickupsCompleted:int │     │ + toMap(): Map              │
│ - totalPickupsPending: int  │     │ + fromMap(): WasteTypeModel │
│ - totalWasteCollected:double│     └─────────────────────────────┘
│ - wasteByCategory: Map      │
│ - activeDrivers: int        │
│ - activeCitizens: int       │
│ - averageResponseTime:double│
│ - reportsOpen: int          │
│ - reportsResolved: int      │
├─────────────────────────────┤
│ + toMap(): Map              │
│ + fromMap(): StatisticsModel│
└─────────────────────────────┘
```

**Figure 4: Class Diagram**

### Class Relationships

| Relationship | Description |
|:---|:---|
| UserModel → CitizenModel | Inheritance - Citizen extends UserModel with address, location, and rewards |
| UserModel → DriverModel | Inheritance - Driver extends UserModel with vehicle and location tracking |
| CitizenModel → PickupRequestModel | Association - Citizen creates pickup requests (1 to many) |
| DriverModel → PickupRequestModel | Association - Driver handles pickup requests (1 to many) |
| DriverModel → RouteModel | Association - Driver follows assigned routes (1 to many) |
| ScheduleModel → LocationModel | Composition - Schedule contains location data |
| ReportModel → LocationModel | Composition - Report contains location data |

---

## Interface Design

The WasteApp interfaces have been designed using modern UI/UX principles, implemented in Flutter for cross-platform compatibility (Android & iOS).

### Citizen Interface Screens

| Screen | Description |
|:---|:---|
| **Splash Screen** | App launch animation with WasteApp branding |
| **Login Screen** | Email/password authentication with role-based routing |
| **Sign Up Screen** | User registration with validation |
| **Home Screen** | Dashboard with stats, quick actions, schedules, and eco-tips |
| **Request Pickup Screen** | Waste type selection, map location, urgency level |
| **Schedule Screen** | View collection schedules (common & personal) |
| **Report Issue Screen** | Issue reporting with categories, photos, and location |
| **Profile Screen** | User profile management and settings |
| **Notifications Screen** | View system notifications and alerts |
| **Rewards Screen** | Eco-points balance and reward history |

### Driver Interface Screens

| Screen | Description |
|:---|:---|
| **Driver Login Screen** | Driver-specific authentication |
| **Driver Dashboard** | Task statistics, assigned pickups, route info |
| **Driver Route Map** | Google Maps integration with pickup markers |
| **Driver Profile** | Driver profile with vehicle information |

### Admin Interface Screens

| Screen | Description |
|:---|:---|
| **Admin Login Screen** | Admin authentication portal |
| **Admin Dashboard** | Analytics overview with key statistics |
| **User Management** | Citizen CRUD operations |
| **Driver Management** | Driver CRUD and vehicle assignment |
| **Schedule Management** | Create and manage collection schedules |
| **Issues Management** | View and resolve citizen reports |
| **Reports Page** | Analytics and data export |
| **Map Overview** | Real-time driver tracking on map |
| **Settings** | System configuration |

**Figure 5: Interface Design Overview**

> **Note:** Detailed interface mockups should be created using Figma or similar design tools and inserted as images in the final report.

---

## Data Design

The data design of the "WasteApp" application organizes the primary entities and their relationships to ensure efficient data storage and retrieval. Firebase Firestore serves as the primary backend database, handling user management, pickup requests, schedules, and real-time updates.

### Database Collections Structure

```
wasteapp-database/
│
├── citizens/                    # Citizen user documents
│   └── {citizenId}/
│       ├── uid: String
│       ├── name: String
│       ├── email: String
│       ├── phone: String
│       ├── address: String
│       ├── location: {lat, lng}
│       ├── rewardPoints: Number
│       ├── wastePreferences: Array
│       └── createdAt: Timestamp
│
├── drivers/                     # Driver user documents
│   └── {driverId}/
│       ├── uid: String
│       ├── name: String
│       ├── email: String
│       ├── vehicleNumber: String
│       ├── vehicleType: String
│       ├── licenseNumber: String
│       ├── isAvailable: Boolean
│       ├── currentLocation: {lat, lng}
│       ├── rating: Number
│       └── completedPickups: Number
│
├── admins/                      # Admin user documents
│   └── {adminId}/
│       ├── uid: String
│       ├── name: String
│       ├── email: String
│       └── createdAt: Timestamp
│
├── pickupRequests/              # Pickup request documents
│   └── {requestId}/
│       ├── citizenId: String (ref)
│       ├── driverId: String (ref)
│       ├── location: {lat, lng, address}
│       ├── wasteType: String
│       ├── status: String
│       ├── requestedDate: Timestamp
│       ├── scheduledDate: Timestamp
│       └── completedDate: Timestamp
│
├── schedules/                   # Collection schedule documents
│   └── {scheduleId}/
│       ├── area: String
│       ├── wasteType: String
│       ├── daysOfWeek: Array
│       ├── collectionTime: String
│       ├── driverId: String (ref)
│       ├── isCommon: Boolean
│       ├── citizenId: String (ref)
│       └── isActive: Boolean
│
├── reports/                     # Issue report documents
│   └── {reportId}/
│       ├── reporterId: String (ref)
│       ├── title: String
│       ├── description: String
│       ├── type: String
│       ├── priority: String
│       ├── status: String
│       ├── location: {lat, lng}
│       ├── imageUrls: Array
│       └── createdAt: Timestamp
│
├── routes/                      # Driver route documents
│   └── {routeId}/
│       ├── name: String
│       ├── driverId: String (ref)
│       ├── waypoints: Array
│       ├── pickupRequestIds: Array
│       ├── status: String
│       └── totalDistance: Number
│
├── notifications/               # User notification documents
│   └── {notificationId}/
│       ├── userId: String (ref)
│       ├── title: String
│       ├── message: String
│       ├── type: String
│       ├── isRead: Boolean
│       └── createdAt: Timestamp
│
└── wasteTypes/                  # Waste category definitions
    └── {wasteTypeId}/
        ├── name: String
        ├── category: String
        ├── description: String
        ├── isRecyclable: Boolean
        └── disposalInstructions: Array
```

### Entity Relationships

| Entity | Relationship | Entity | Description |
|:---|:---:|:---|:---|
| Citizen | 1 : N | PickupRequest | Citizen creates multiple pickup requests |
| Driver | 1 : N | PickupRequest | Driver handles multiple pickups |
| Driver | 1 : N | Route | Driver is assigned multiple routes |
| Schedule | N : 1 | Driver | Multiple schedules assigned to driver |
| Citizen | 1 : N | Report | Citizen submits multiple reports |
| Admin | 1 : N | Report | Admin resolves multiple reports |

**Figure 7: Data Design Diagram**

---

## Module Design

The WasteApp system is divided into functional modules that handle specific aspects of the application. Each module operates independently while communicating through defined interfaces.

### System Modules

```
┌─────────────────────────────────────────────────────────────────┐
│                      WasteApp System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │Authentication │  │  User Module  │  │ Pickup Module │       │
│  │    Module     │  │               │  │               │       │
│  ├───────────────┤  ├───────────────┤  ├───────────────┤       │
│  │- Login        │  │- Citizen Mgmt │  │- Create Request│      │
│  │- Register     │  │- Driver Mgmt  │  │- Assign Driver │      │
│  │- Logout       │  │- Admin Mgmt   │  │- Update Status │      │
│  │- Password     │  │- Profile Mgmt │  │- View History  │      │
│  │  Reset        │  │               │  │                │      │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │Schedule Module│  │ Report Module │  │Location Module│       │
│  │               │  │               │  │               │       │
│  ├───────────────┤  ├───────────────┤  ├───────────────┤       │
│  │- View Schedule│  │- Submit Report│  │- GPS Tracking │       │
│  │- Create       │  │- View Issues  │  │- Map Display  │       │
│  │- Edit         │  │- Assign Issue │  │- Route Nav    │       │
│  │- Delete       │  │- Resolve      │  │- Driver Track │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │ Route Module  │  │Notification   │  │ Analytics     │       │
│  │               │  │   Module      │  │   Module      │       │
│  ├───────────────┤  ├───────────────┤  ├───────────────┤       │
│  │- Create Route │  │- Send Notif   │  │- Dashboard    │       │
│  │- Assign Driver│  │- View Notif   │  │- Reports      │       │
│  │- View Route   │  │- Mark Read    │  │- Statistics   │       │
│  │- Update Status│  │- Push Alerts  │  │- Export Data  │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │            Firebase Backend             │
        ├─────────────────────────────────────────┤
        │ - Firebase Authentication               │
        │ - Cloud Firestore Database              │
        │ - Firebase Cloud Storage                │
        │ - Firebase Cloud Messaging              │
        └─────────────────────────────────────────┘
```

**Figure 8: Module Design Diagram**

---

## Pseudo Codes

### User Registration

**Table 1: User Registration Pseudo Code**

```
Function userRegistration(name, email, password, phone, address):
    If email and password are valid:
        Try:
            Create user account in Firebase Authentication
            Create UserModel with provided details
            Save user to Firestore 'citizens' collection
            Return "Registration Successful"
        Catch error:
            Return "Registration Failed: " + error message
    Else:
        Return "Invalid Input - Please check all fields"
```

---

### User Login

**Table 2: User Login Pseudo Code**

```
Function userLogin(email, password):
    If email and password are not empty:
        Try:
            Authenticate with Firebase using email/password
            Get user credentials
            Fetch user role from Firestore
            If role == 'citizen':
                Navigate to Citizen Dashboard
            Else If role == 'driver':
                Navigate to Driver Dashboard
            Else If role == 'admin':
                Navigate to Admin Dashboard
            Return "Login Successful"
        Catch error:
            Return "Login Failed - Invalid credentials"
    Else:
        Return "Please enter email and password"
```

---

### Request Waste Pickup

**Table 3: Request Waste Pickup Pseudo Code**

```
Function requestPickup(citizenId, location, wasteType, urgency, notes):
    If citizenId and location are valid:
        Create PickupRequestModel with:
            - citizenId
            - location (latitude, longitude, address)
            - wasteType
            - status = 'pending'
            - requestedDate = current timestamp
            - specialInstructions = notes
        
        Save pickup request to Firestore 'pickupRequests' collection
        Create notification for admin
        Return "Pickup Request Submitted Successfully"
    Else:
        Return "Invalid Request - Please select location"
```

---

### Assign Driver to Pickup

**Table 4: Assign Driver to Pickup Pseudo Code**

```
Function assignDriverToPickup(pickupId, driverId):
    If pickupId exists in Firestore:
        Update pickup request with:
            - driverId = driverId
            - status = 'assigned'
            - scheduledDate = current timestamp
        
        Create notification for driver
        Create notification for citizen
        Return "Driver Assigned Successfully"
    Else:
        Return "Pickup Request Not Found"
```

---

### Update Pickup Status

**Table 5: Update Pickup Status Pseudo Code**

```
Function updatePickupStatus(pickupId, newStatus):
    If pickupId exists in Firestore:
        If newStatus == 'completed':
            Update pickup request with:
                - status = 'completed'
                - completedDate = current timestamp
            Increment driver's completedPickups count
            Add reward points to citizen
        Else:
            Update pickup request with:
                - status = newStatus
        
        Send notification to citizen
        Return "Status Updated Successfully"
    Else:
        Return "Pickup Request Not Found"
```

---

### Report Issue

**Table 6: Report Issue Pseudo Code**

```
Function reportIssue(reporterId, title, description, type, location, images):
    If reporterId and description are valid:
        Create ReportModel with:
            - reporterId
            - title
            - description
            - type (missed_pickup, illegal_dumping, bin_issue, other)
            - priority = 'medium'
            - status = 'open'
            - location = location coordinates
            - imageUrls = uploaded image URLs
            - createdAt = current timestamp
        
        Save report to Firestore 'reports' collection
        Notify admin of new issue
        Return "Issue Reported Successfully"
    Else:
        Return "Please provide issue details"
```

---

### Create Collection Schedule

**Table 7: Create Collection Schedule Pseudo Code**

```
Function createSchedule(area, wasteType, daysOfWeek, time, driverId, isCommon):
    If area and wasteType are valid:
        Create ScheduleModel with:
            - area
            - wasteType
            - daysOfWeek = [selected days]
            - collectionTime = time
            - driverId = driverId (optional)
            - isCommon = isCommon
            - isActive = true
            - createdAt = current timestamp
        
        Save schedule to Firestore 'schedules' collection
        If isCommon == true:
            Notify all citizens in area
        Return "Schedule Created Successfully"
    Else:
        Return "Invalid Schedule Details"
```

---

### View Driver Location on Map

**Table 8: View Driver Location on Map Pseudo Code**

```
Function viewDriversOnMap():
    Subscribe to Firestore 'drivers' collection real-time updates
    For each driver document:
        If driver.isAvailable == true AND driver.currentLocation exists:
            Create map marker at driver's location
            Display driver name and vehicle info
    
    Render all markers on Google Map
    Return "Drivers Displayed on Map"
```

---

### Real-Time Location Updates

**Table 9: Real-Time Location Updates Pseudo Code**

```
Function updateDriverLocation(driverId, latitude, longitude):
    If driverId is valid:
        Update driver document in Firestore with:
            - currentLocation = {latitude, longitude}
            - lastUpdated = current timestamp
        
        Broadcast location to subscribed admin clients
        Return "Location Updated"
    Else:
        Return "Invalid Driver ID"
```

---

### Send Notification

**Table 10: Send Notification Pseudo Code**

```
Function sendNotification(userId, title, message, type, entityId):
    Create NotificationModel with:
        - userId
        - title
        - message
        - type (pickup_scheduled, pickup_completed, schedule_reminder, etc.)
        - relatedEntityId = entityId
        - isRead = false
        - createdAt = current timestamp
    
    Save notification to Firestore 'notifications' collection
    Trigger Firebase Cloud Messaging push notification
    Return "Notification Sent"
```

---

## Summary

This chapter has presented the comprehensive system design for the WasteApp application, covering:

1. **Class Diagram** - Object-oriented structure with 10 primary model classes showing inheritance and associations
2. **Interface Design** - User interfaces for Citizens, Drivers, and Administrators
3. **Data Design** - Firebase Firestore database structure with 8 main collections
4. **Module Design** - 9 functional modules handling authentication, users, pickups, schedules, reports, locations, routes, notifications, and analytics
5. **Pseudo Codes** - 10 key algorithms covering registration, login, pickup requests, driver assignment, status updates, issue reporting, scheduling, map tracking, location updates, and notifications

These design elements provide a solid foundation for the implementation phase, ensuring scalability, maintainability, and efficient functionality of the waste management system.
