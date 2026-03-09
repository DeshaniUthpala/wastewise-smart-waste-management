# CHAPTER 4: IMPLEMENTATION AND TESTING OF THE SYSTEM

## Introduction

This chapter focuses on the implementation and testing of the "WasteApp" mobile application. It outlines how the system design was translated into a functional application using Flutter for development, Firebase for backend services, and Google Maps API for location-based features. The testing phase ensured the app's reliability and usability through unit, integration, and user testing. This ensures the application meets its objectives effectively and functions seamlessly in real-world scenarios.

---

## Developed Interfaces

The WasteApp application features a comprehensive set of user interfaces designed for three distinct user roles: Citizens, Drivers, and Administrators. Each interface has been crafted to provide an intuitive and efficient user experience.

### Citizen Interface Screens

| Figure | Screen Name | Description |
|:------:|:------------|:------------|
| Figure 11 | Splash Screen | App launch animation with WasteApp branding and loading indicator |
| Figure 12 | Login Screen | Email/password authentication with role-based routing options |
| Figure 13 | Sign Up Screen | User registration with name, email, password, phone, and address fields |
| Figure 14 | Home Screen | Dashboard displaying stats, quick actions, upcoming collections, and eco-tips |
| Figure 15 | Request Pickup Screen | Waste type selection, map location picker, urgency level, and special instructions |
| Figure 16 | Schedule Screen | View collection schedules (common & personal) with color-coded waste types |
| Figure 17 | Report Issue Screen | Issue reporting with categories, photos, location, and description |
| Figure 18 | Profile Screen | User profile management with personal information and settings |
| Figure 19 | Notifications Screen | View system notifications and pickup alerts |
| Figure 20 | Rewards Screen | Eco-points balance and reward history |

> **Note:** Insert actual screenshots of the developed interfaces in the final report.

---

### Driver Interface Screens

| Figure | Screen Name | Description |
|:------:|:------------|:------------|
| Figure 21 | Driver Login Screen | Driver-specific authentication portal |
| Figure 22 | Driver Dashboard | Task statistics, assigned pickups count, and route information |
| Figure 23 | Driver Route Map | Google Maps integration with pickup location markers and navigation |

---

### Admin Interface Screens

| Figure | Screen Name | Description |
|:------:|:------------|:------------|
| Figure 24 | Admin Login Screen | Admin authentication portal with secure access |
| Figure 25 | Admin Dashboard | Analytics overview with key statistics and real-time metrics |
| Figure 26 | User Management | Citizen CRUD operations with search and filter capabilities |
| Figure 27 | Driver Management | Driver CRUD, vehicle assignment, and status monitoring |
| Figure 28 | Schedule Management | Create and manage collection schedules for areas |
| Figure 29 | Issues Management | View and resolve citizen-reported issues |
| Figure 30 | Reports Page | Analytics, data visualization, and export functionality |
| Figure 31 | Map Overview | Real-time driver tracking on interactive map |
| Figure 32 | Settings | System configuration and admin profile management |

---

## Discussion with Key Components and Domain Data

### Key Components

The WasteApp mobile application simplifies waste management operations for citizens, drivers, and administrators through the integration of essential components:

**User Management**
The system manages user registration, login, and role-based profiles (citizen, driver, or admin), ensuring secure access and personalized experiences. Firebase Authentication handles credential management with email/password authentication.

**Pickup Request Management**
Citizens can easily create waste pickup requests, specifying waste type, location (via Google Maps), urgency level, and special instructions. The system tracks request status from pending through completion.

**Schedule Management**
Administrators can create and manage collection schedules for specific areas. The system supports both common schedules (visible to all citizens in an area) and personal schedules linked to individual pickup requests.

**Driver Assignment & Tracking**
Drivers are assigned to pickup requests and routes by administrators. Real-time GPS tracking allows administrators to monitor driver locations on an interactive map, ensuring efficient route management.

**Search and Filter**
Administrators can search and filter users, drivers, schedules, and reports using various criteria, ensuring efficient management of large datasets.

**Map Integration**
The app leverages the Google Maps API to provide:
- Citizens with location selection for pickup requests
- Drivers with navigation to pickup locations
- Administrators with real-time driver tracking and route visualization

**Real-Time Updates**
Using Firebase Firestore's real-time capabilities, pickup requests, schedules, and driver locations are kept up-to-date, ensuring all users have access to the latest information.

**Issue Reporting**
Citizens can report issues such as missed pickups, illegal dumping, bin problems, or other concerns with attached photos and location data. Administrators can view, assign, and resolve these issues.

**Notification System**
The application sends notifications for pickup confirmations, schedule reminders, status updates, and system alerts using Firebase Cloud Messaging.

**Reward System**
Citizens earn eco-points for completed pickups, encouraging participation in proper waste disposal practices.

---

### Domain Data

The WasteApp system manages the following domain data:

**User Data**
- Name, email, hashed password (Firebase Auth)
- Phone number, profile picture URL
- Role (citizen/driver/admin)
- Created date, last login timestamp
- Active status

**Citizen-Specific Data**
- Address, location coordinates
- Reward points balance
- Waste preferences list

**Driver-Specific Data**
- Vehicle ID, vehicle number, vehicle type
- License number
- Availability status
- Current location (real-time GPS)
- Rating, completed pickups count

**Pickup Request Data**
- Citizen ID (reference), Driver ID (reference)
- Location (latitude, longitude, address)
- Waste type, waste category
- Estimated weight
- Status (pending/assigned/in_progress/completed/cancelled)
- Requested date, scheduled date, completed date
- Special instructions, image URLs, rating

**Schedule Data**
- Area name, waste type
- Days of week, collection time
- Driver ID (reference), Route ID (reference)
- Is common (boolean), Citizen ID (for personal schedules)
- Active status, description

**Report Data**
- Reporter ID, title, description
- Type (missed_pickup/illegal_dumping/bin_issue/other)
- Priority (low/medium/high/critical)
- Status (open/in_progress/resolved/closed)
- Location, image URLs
- Created date, resolved date, resolution notes

**Route Data**
- Name, Driver ID
- Waypoints list, pickup request IDs
- Status, start/end times
- Total distance, estimated duration

**Notification Data**
- User ID, title, message
- Type, related entity ID
- Read status, timestamps

---

## Deploy the System and Test with Real Data

The final stage of the WasteApp project involved deploying the mobile application for real-world use and conducting tests with actual data to validate its functionality and usability. This phase was critical in assessing the app's performance under real-life conditions and ensuring it met the needs of citizens, drivers, and administrators.

### Deployment

The application was deployed on Android devices, leveraging Firebase for backend services and the Google Maps API for location-based features. The deployment process included the following steps:

**Preparing the Application**
- Finalized the codebase in Flutter and ensured compatibility with various Android devices
- Configured Firebase for real-time database management, authentication, and storage
- Integrated Google Maps API with proper API keys for location services
- Tested on multiple screen sizes and Android versions

**Publishing the App**
- Generated an APK (Android Package Kit) file for installation
- Distributed the application to a group of test users using direct APK sharing
- Set up Firebase project with production security rules

---

### Testing with Real Data

**User Registration & Authentication**
- Citizens registered accounts with real email addresses and personal details
- Login functionality tested with valid and invalid credentials
- Role-based routing verified for citizens, drivers, and administrators
- Password reset functionality validated via email

**Pickup Request Workflow**
- Citizens created pickup requests with actual locations using GPS
- Waste type selection and urgency levels tested
- Administrators assigned drivers to pending requests
- Status updates tracked through the complete lifecycle
- Completion confirmations and ratings verified

**Schedule Management**
- Administrators created collection schedules for different areas
- Common schedules displayed to all users in specified areas
- Personal schedules linked to individual pickup requests
- Real-time updates verified when schedules were modified

**Map Integration**
- Location selection tested using Google Maps picker
- Driver navigation to pickup locations validated
- Real-time driver tracking on admin map overview confirmed
- Proximity calculations and route optimization tested

**Issue Reporting**
- Citizens reported various issue types with photos and descriptions
- Location tagging via GPS verified
- Admin issue management workflow tested
- Resolution notes and status updates confirmed

**Real-Time Synchronization**
- Data updates synchronized across multiple devices
- Firebase Firestore listeners confirmed working
- Push notifications delivered successfully

---

## Test with Simulated Data

**Table 9: Test with Simulated Data**

| No | Task Process | Expected Result | Actual Result | Status |
|:--:|:-------------|:----------------|:--------------|:------:|
| 1 | User Registration | User account is created and saved in Firebase; user redirected to the homepage | User registered successfully and redirected to the homepage | Pass |
| 2 | User Login | User logs in and is redirected to the homepage | User login successful | Pass |
| 3 | Invalid Login Attempt | Users enter incorrect credentials during login | Displays an error message indicating invalid credentials | Pass |
| 4 | Create Pickup Request | Pickup request is saved in Firebase and visible to admin | Pickup request added successfully and visible in the app | Pass |
| 5 | Update Pickup Status | Updated pickup status is saved in Firebase and reflected in the app | Pickup status updated successfully and changes visible to users | Pass |
| 6 | Cancel Pickup Request | Pickup request status changed to cancelled and no longer active | Pickup request cancelled successfully and removed from active list | Pass |
| 7 | Search for Schedules | Schedules matching the search criteria (e.g., area, waste type) are displayed | Search results displayed correctly based on filters | Pass |
| 8 | View Pickups on Map | Pickup locations are displayed on a map with accurate markers and details | Pickups displayed on map with correct markers and locations | Pass |
| 9 | View Collection Schedule | Schedules are displayed in a list view with collection times and waste types | Schedules listed correctly in schedule view with detailed information | Pass |
| 10 | Assign Driver to Pickup | Admin can assign a driver to a pending pickup request | Driver assigned successfully and pickup status updated | Pass |
| 11 | View Pickup Request Details | Detailed pickup information, including waste type, location, and status, is displayed | Pickup details displayed correctly as per the request data | Pass |
| 12 | Forgot Password Functionality | User can reset their password securely via email | Password reset email sent successfully; password updated correctly | Pass |
| 13 | Google Maps Integration | Map displays pickup locations and allows navigation to selected locations | Map integration successful; pickups and navigation functional | Pass |
| 14 | Logout | User is logged out and redirected to the login screen | Logout successful; login screen displayed | Pass |
| 15 | Add New Schedule (Admin) | Schedule is saved in Firebase and visible to citizens in the area | Schedule added successfully and visible in schedule list | Pass |
| 16 | Edit Schedule (Admin) | Updated schedule details are saved in Firebase and reflected in the app | Schedule details updated successfully and changes visible | Pass |
| 17 | Delete Schedule (Admin) | Schedule is removed from Firebase and no longer visible in the app | Schedule deleted successfully and removed from the app | Pass |
| 18 | Report Issue | Issue report is saved in Firebase with photos and location data | Issue reported successfully with all attachments | Pass |
| 19 | Resolve Issue (Admin) | Issue status updated to resolved with resolution notes | Issue resolved successfully and status updated | Pass |
| 20 | Driver Location Tracking | Driver's current location is updated in real-time and visible on admin map | Driver location displayed on map with correct real-time updates | Pass |
| 21 | Add New Driver (Admin) | Driver account is created and saved in Firebase with vehicle details | Driver added successfully and visible in driver management | Pass |
| 22 | Edit Driver Details (Admin) | Updated driver details are saved in Firebase and reflected in the app | Driver details updated successfully and changes visible | Pass |
| 23 | Delete Driver (Admin) | Driver account is deactivated and no longer visible in active driver list | Driver removed successfully and removed from active list | Pass |
| 24 | View Notifications | User can view list of notifications with read/unread status | Notifications displayed correctly with proper formatting | Pass |
| 25 | Mark Notification as Read | Notification status updated to read and visual indicator changes | Notification marked as read successfully | Pass |
| 26 | View Admin Dashboard Statistics | Real-time statistics displayed including pickup counts and user metrics | Statistics displayed correctly with accurate data | Pass |
| 27 | Driver Accept Pickup | Driver accepts assigned pickup and status updates to in_progress | Pickup status updated successfully; driver can navigate | Pass |
| 28 | Driver Complete Pickup | Driver marks pickup as completed; citizen receives notification | Pickup completed successfully; reward points added | Pass |
| 29 | View Reward Points | Citizen can view their eco-points balance and history | Reward points displayed correctly in profile/rewards screen | Pass |
| 30 | Filter Users (Admin) | Admin can filter users by role, status, or search query | Users filtered correctly based on selected criteria | Pass |

---

## Summary

This chapter has detailed the implementation and testing of the WasteApp mobile application:

1. **Implementation** - The application was developed using Flutter for cross-platform compatibility, Firebase for backend services (Authentication, Firestore, Storage, Cloud Messaging), and Google Maps API for location-based features.

2. **Developed Interfaces** - A total of 22 screens were implemented across three user roles:
   - 10 Citizen screens for waste management and profile features
   - 3 Driver screens for pickup management and navigation
   - 9 Admin screens for system management and analytics

3. **Key Components** - The system integrates user management, pickup request workflow, schedule management, real-time driver tracking, map integration, issue reporting, and notification systems.

4. **Testing** - Comprehensive testing was conducted with 30 test cases covering all major functionalities. All tests passed successfully, validating the system's reliability and usability.

5. **Deployment** - The application was deployed on Android devices and tested with real users and data, confirming its readiness for production use.

The successful implementation and testing demonstrate that WasteApp effectively addresses the requirements for smart waste management, providing a seamless experience for citizens, drivers, and administrators.
