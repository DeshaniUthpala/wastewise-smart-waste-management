# WasteWise - Pseudo Codes

## Table of Contents
1. [User Registration (Sign Up)](#1-user-registration-sign-up)
2. [User Login](#2-user-login)
3. [Forgot Password](#3-forgot-password)
4. [Citizen: Request Pickup](#4-citizen-request-pickup)
5. [Citizen: View Schedule](#5-citizen-view-schedule)
6. [Citizen: Report Issue](#6-citizen-report-issue)
7. [Driver: View Assigned Pickups](#7-driver-view-assigned-pickups)
8. [Driver: Update Pickup Status](#8-driver-update-pickup-status)
9. [Driver: Update Location](#9-driver-update-location)
10. [Admin: Assign Driver to Pickup](#10-admin-assign-driver-to-pickup)
11. [Admin: Manage Citizens](#11-admin-manage-citizens)
12. [Admin: Manage Drivers](#12-admin-manage-drivers)
13. [Admin: View Dashboard Statistics](#13-admin-view-dashboard-statistics)
14. [Admin: Resolve Report](#14-admin-resolve-report)

---

## 1. User Registration (Sign Up)

**Table 1: User Registration Pseudo Code**

```
FUNCTION userSignUp(name, email, password, role, phone, address):
    BEGIN
        // Validate input fields
        IF email is empty OR password is empty OR name is empty THEN
            RETURN "Error: Please fill all required fields"
        END IF
        
        IF password length < 6 THEN
            RETURN "Error: Password must be at least 6 characters"
        END IF
        
        IF email format is invalid THEN
            RETURN "Error: Invalid email format"
        END IF
        
        TRY:
            // Create user in Firebase Authentication
            userCredential = FirebaseAuth.createUserWithEmailAndPassword(email, password)
            userId = userCredential.user.uid
            
            // Create user document in Firestore based on role
            userData = {
                uid: userId,
                name: name,
                email: email,
                phone: phone,
                role: role,
                address: address,
                createdAt: currentTimestamp(),
                isActive: true
            }
            
            IF role == 'citizen' THEN
                userData.rewardPoints = 0
                userData.wastePreferences = []
                SAVE userData to Firestore collection 'citizens' with document ID = userId
            ELSE IF role == 'driver' THEN
                userData.isAvailable = true
                userData.completedPickups = 0
                SAVE userData to Firestore collection 'drivers' with document ID = userId
            ELSE IF role == 'admin' THEN
                SAVE userData to Firestore collection 'admins' with document ID = userId
            END IF
            
            RETURN "Registration Successful"
            
        CATCH FirebaseAuthException:
            IF error code == 'email-already-in-use' THEN
                RETURN "Error: Email already registered"
            ELSE IF error code == 'weak-password' THEN
                RETURN "Error: Password is too weak"
            ELSE IF error code == 'invalid-email' THEN
                RETURN "Error: Invalid email address"
            ELSE
                RETURN "Error: Registration failed - " + error message
            END IF
        END TRY
    END FUNCTION
```

---

## 2. User Login

**Table 2: User Login Pseudo Code**

```
FUNCTION userLogin(email, password, role):
    BEGIN
        // Validate input
        IF email is empty OR password is empty THEN
            RETURN "Error: Please enter email and password"
        END IF
        
        TRY:
            // Authenticate with Firebase
            userCredential = FirebaseAuth.signInWithEmailAndPassword(email, password)
            userId = userCredential.user.uid
            
            // Fetch user data from Firestore based on role
            IF role == 'citizen' THEN
                userDoc = GET document from 'citizens' collection where document ID = userId
            ELSE IF role == 'driver' THEN
                userDoc = GET document from 'drivers' collection where document ID = userId
            ELSE IF role == 'admin' THEN
                userDoc = GET document from 'admins' collection where document ID = userId
            END IF
            
            IF userDoc does not exist THEN
                RETURN "Error: User not found"
            END IF
            
            userData = userDoc.data()
            
            // Check if user is active
            IF userData.isActive == false THEN
                RETURN "Error: Account is deactivated"
            END IF
            
            // Update last login timestamp
            UPDATE userDoc with lastLogin = currentTimestamp()
            
            // Navigate based on role
            IF role == 'citizen' THEN
                NAVIGATE to Citizen Home Screen
            ELSE IF role == 'driver' THEN
                NAVIGATE to Driver Dashboard
            ELSE IF role == 'admin' THEN
                NAVIGATE to Admin Dashboard
            END IF
            
            RETURN "Login Successful"
            
        CATCH FirebaseAuthException:
            IF error code == 'user-not-found' THEN
                RETURN "Error: No user found with this email"
            ELSE IF error code == 'wrong-password' THEN
                RETURN "Error: Incorrect password"
            ELSE IF error code == 'invalid-credential' THEN
                RETURN "Error: Invalid email or password"
            ELSE
                RETURN "Error: Login failed - " + error message
            END IF
        END TRY
    END FUNCTION
```

---

## 3. Forgot Password

**Table 3: Forgot Password Pseudo Code**

```
FUNCTION forgotPassword(email):
    BEGIN
        // Validate email
        IF email is empty THEN
            RETURN "Error: Please enter your email address"
        END IF
        
        IF email format is invalid THEN
            RETURN "Error: Invalid email format"
        END IF
        
        TRY:
            // Send password reset email via Firebase
            FirebaseAuth.sendPasswordResetEmail(email)
            
            RETURN "Success: Password reset email sent. Please check your inbox."
            
        CATCH FirebaseAuthException:
            IF error code == 'user-not-found' THEN
                RETURN "Error: No account found with this email"
            ELSE IF error code == 'invalid-email' THEN
                RETURN "Error: Invalid email address"
            ELSE
                RETURN "Error: Failed to send reset email - " + error message
            END IF
        END TRY
    END FUNCTION
```

---

## 4. Citizen: Request Pickup

**Table 4: Citizen Request Pickup Pseudo Code**

```
FUNCTION requestPickup(citizenId, location, wasteType, urgency, notes):
    BEGIN
        // Validate input
        IF citizenId is empty THEN
            RETURN "Error: User not authenticated"
        END IF
        
        IF location is null OR location.latitude is null OR location.longitude is null THEN
            RETURN "Error: Please select a pickup location"
        END IF
        
        IF wasteType is empty THEN
            RETURN "Error: Please select a waste type"
        END IF
        
        // Get current user
        currentUser = FirebaseAuth.getCurrentUser()
        
        IF currentUser is null OR currentUser.uid != citizenId THEN
            RETURN "Error: Authentication required"
        END IF
        
        TRY:
            // Create pickup request model
            pickupRequest = {
                citizenId: citizenId,
                driverId: null,
                location: {
                    latitude: location.latitude,
                    longitude: location.longitude,
                    address: location.address,
                    city: location.city,
                    postalCode: location.postalCode
                },
                wasteType: wasteType,
                status: 'pending',
                requestedDate: currentTimestamp(),
                scheduledDate: null,
                completedDate: null,
                specialInstructions: notes,
                estimatedWeight: null,
                urgency: urgency
            }
            
            // Save to Firestore
            requestId = SAVE pickupRequest to 'pickupRequests' collection
            // Returns auto-generated document ID
            
            // Create notification for admin
            notification = {
                userId: 'admin', // or specific admin IDs
                title: 'New Pickup Request',
                message: 'A new pickup request has been submitted',
                type: 'pickup_scheduled',
                relatedEntityId: requestId,
                relatedEntityType: 'pickup_request',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE notification to 'notifications' collection
            
            // Create notification for citizen
            citizenNotification = {
                userId: citizenId,
                title: 'Pickup Request Submitted',
                message: 'Your pickup request has been submitted successfully',
                type: 'pickup_scheduled',
                relatedEntityId: requestId,
                relatedEntityType: 'pickup_request',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE citizenNotification to 'notifications' collection
            
            RETURN "Success: Pickup request submitted successfully"
            
        CATCH Exception:
            RETURN "Error: Failed to submit pickup request - " + error message
        END TRY
    END FUNCTION
```

---

## 5. Citizen: View Schedule

**Table 5: Citizen View Schedule Pseudo Code**

```
FUNCTION viewSchedule(citizenId):
    BEGIN
        // Validate input
        IF citizenId is empty THEN
            RETURN "Error: User not authenticated"
        END IF
        
        TRY:
            schedules = []
            
            // Get common schedules (visible to all citizens)
            commonSchedulesQuery = QUERY 'schedules' collection WHERE:
                isCommon == true AND
                isActive == true
            ORDER BY createdAt DESCENDING
            
            commonSchedules = EXECUTE commonSchedulesQuery
            
            FOR EACH schedule IN commonSchedules:
                ADD schedule to schedules
            END FOR
            
            // Get personal schedules (specific to this citizen)
            personalSchedulesQuery = QUERY 'schedules' collection WHERE:
                citizenId == citizenId AND
                isActive == true
            ORDER BY createdAt DESCENDING
            
            personalSchedules = EXECUTE personalSchedulesQuery
            
            FOR EACH schedule IN personalSchedules:
                ADD schedule to schedules
            END FOR
            
            // Sort all schedules by creation date
            SORT schedules by createdAt DESCENDING
            
            RETURN schedules
            
        CATCH Exception:
            RETURN "Error: Failed to fetch schedules - " + error message
        END TRY
    END FUNCTION
```

---

## 6. Citizen: Report Issue

**Table 6: Citizen Report Issue Pseudo Code**

```
FUNCTION reportIssue(reporterId, title, description, type, priority, location, imageUrls):
    BEGIN
        // Validate input
        IF reporterId is empty THEN
            RETURN "Error: User not authenticated"
        END IF
        
        IF title is empty OR description is empty THEN
            RETURN "Error: Please fill all required fields"
        END IF
        
        IF type is empty THEN
            RETURN "Error: Please select issue type"
        END IF
        
        TRY:
            // Create report model
            report = {
                reporterId: reporterId,
                title: title,
                description: description,
                type: type, // 'missed_pickup', 'illegal_dumping', 'bin_issue', 'other'
                priority: priority, // 'low', 'medium', 'high', 'urgent'
                status: 'open',
                location: location,
                imageUrls: imageUrls,
                createdAt: currentTimestamp(),
                resolvedAt: null,
                assignedTo: null,
                resolutionNotes: null
            }
            
            // Save to Firestore
            reportId = SAVE report to 'reports' collection
            
            // Create notification for admin
            notification = {
                userId: 'admin',
                title: 'New Issue Reported',
                message: title,
                type: 'report_created',
                relatedEntityId: reportId,
                relatedEntityType: 'report',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE notification to 'notifications' collection
            
            RETURN "Success: Issue reported successfully"
            
        CATCH Exception:
            RETURN "Error: Failed to submit report - " + error message
        END TRY
    END FUNCTION
```

---

## 7. Driver: View Assigned Pickups

**Table 7: Driver View Assigned Pickups Pseudo Code**

```
FUNCTION viewAssignedPickups(driverId, status):
    BEGIN
        // Validate input
        IF driverId is empty THEN
            RETURN "Error: Driver not authenticated"
        END IF
        
        TRY:
            // Build query
            query = QUERY 'pickupRequests' collection WHERE:
                driverId == driverId
            
            IF status is not null THEN
                query = query WHERE status == status
            END IF
            
            query = query ORDER BY requestedDate DESCENDING
            
            // Execute query and get real-time stream
            pickupRequests = EXECUTE query
            
            RETURN pickupRequests // Returns list of PickupRequestModel objects
            
        CATCH Exception:
            RETURN "Error: Failed to fetch assigned pickups - " + error message
        END TRY
    END FUNCTION
```

---

## 8. Driver: Update Pickup Status

**Table 8: Driver Update Pickup Status Pseudo Code**

```
FUNCTION updatePickupStatus(pickupId, driverId, newStatus, notes):
    BEGIN
        // Validate input
        IF pickupId is empty OR driverId is empty THEN
            RETURN "Error: Invalid request"
        END IF
        
        IF newStatus is empty THEN
            RETURN "Error: Please select a status"
        END IF
        
        // Validate status values
        validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled']
        IF newStatus NOT IN validStatuses THEN
            RETURN "Error: Invalid status"
        END IF
        
        TRY:
            // Get pickup request
            pickupRequest = GET document from 'pickupRequests' collection where document ID = pickupId
            
            IF pickupRequest does not exist THEN
                RETURN "Error: Pickup request not found"
            END IF
            
            // Verify driver is assigned to this pickup
            IF pickupRequest.driverId != driverId THEN
                RETURN "Error: You are not assigned to this pickup"
            END IF
            
            // Prepare update data
            updateData = {
                status: newStatus
            }
            
            IF newStatus == 'completed' THEN
                updateData.completedDate = currentTimestamp()
                
                // Update driver's completed pickups count
                driverDoc = GET document from 'drivers' collection where document ID = driverId
                currentCount = driverDoc.data().completedPickups
                UPDATE driverDoc with completedPickups = currentCount + 1
            END IF
            
            IF notes is not empty THEN
                updateData.notes = notes
            END IF
            
            // Update pickup request
            UPDATE pickupRequest with updateData
            
            // Create notification for citizen
            citizenNotification = {
                userId: pickupRequest.citizenId,
                title: 'Pickup Status Updated',
                message: 'Your pickup request status has been updated to ' + newStatus,
                type: 'pickup_status_updated',
                relatedEntityId: pickupId,
                relatedEntityType: 'pickup_request',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE citizenNotification to 'notifications' collection
            
            RETURN "Success: Pickup status updated successfully"
            
        CATCH Exception:
            RETURN "Error: Failed to update status - " + error message
        END TRY
    END FUNCTION
```

---

## 9. Driver: Update Location

**Table 9: Driver Update Location Pseudo Code**

```
FUNCTION updateDriverLocation(driverId, latitude, longitude):
    BEGIN
        // Validate input
        IF driverId is empty THEN
            RETURN "Error: Driver not authenticated"
        END IF
        
        IF latitude is null OR longitude is null THEN
            RETURN "Error: Invalid location coordinates"
        END IF
        
        TRY:
            // Get driver document
            driverDoc = GET document from 'drivers' collection where document ID = driverId
            
            IF driverDoc does not exist THEN
                RETURN "Error: Driver not found"
            END IF
            
            // Update driver location
            updateData = {
                currentLocation: {
                    latitude: latitude,
                    longitude: longitude
                },
                lastActive: currentTimestamp(),
                isOnline: true
            }
            
            UPDATE driverDoc with updateData
            
            RETURN "Success: Location updated"
            
        CATCH Exception:
            RETURN "Error: Failed to update location - " + error message
        END TRY
    END FUNCTION
```

---

## 10. Admin: Assign Driver to Pickup

**Table 10: Admin Assign Driver to Pickup Pseudo Code**

```
FUNCTION assignDriverToPickup(pickupId, driverId, adminId):
    BEGIN
        // Validate input
        IF pickupId is empty OR driverId is empty THEN
            RETURN "Error: Invalid request"
        END IF
        
        // Verify admin permissions
        adminDoc = GET document from 'admins' collection where document ID = adminId
        IF adminDoc does not exist THEN
            RETURN "Error: Unauthorized access"
        END IF
        
        TRY:
            // Get pickup request
            pickupRequest = GET document from 'pickupRequests' collection where document ID = pickupId
            
            IF pickupRequest does not exist THEN
                RETURN "Error: Pickup request not found"
            END IF
            
            // Check if pickup is already assigned
            IF pickupRequest.status == 'assigned' OR pickupRequest.status == 'completed' THEN
                RETURN "Error: Pickup request is already assigned or completed"
            END IF
            
            // Get driver document
            driverDoc = GET document from 'drivers' collection where document ID = driverId
            
            IF driverDoc does not exist THEN
                RETURN "Error: Driver not found"
            END IF
            
            // Check if driver is available
            IF driverDoc.data().isAvailable == false THEN
                RETURN "Error: Driver is not available"
            END IF
            
            // Update pickup request
            UPDATE pickupRequest with {
                driverId: driverId,
                status: 'assigned',
                scheduledDate: currentTimestamp()
            }
            
            // Create notification for driver
            driverNotification = {
                userId: driverId,
                title: 'New Pickup Assigned',
                message: 'You have been assigned a new pickup request',
                type: 'pickup_assigned',
                relatedEntityId: pickupId,
                relatedEntityType: 'pickup_request',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE driverNotification to 'notifications' collection
            
            // Create notification for citizen
            citizenNotification = {
                userId: pickupRequest.citizenId,
                title: 'Driver Assigned',
                message: 'A driver has been assigned to your pickup request',
                type: 'pickup_assigned',
                relatedEntityId: pickupId,
                relatedEntityType: 'pickup_request',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE citizenNotification to 'notifications' collection
            
            RETURN "Success: Driver assigned successfully"
            
        CATCH Exception:
            RETURN "Error: Failed to assign driver - " + error message
        END TRY
    END FUNCTION
```

---

## 11. Admin: Manage Citizens

**Table 11: Admin Manage Citizens Pseudo Code**

```
FUNCTION manageCitizens(adminId, action, citizenId, updateData):
    BEGIN
        // Verify admin permissions
        adminDoc = GET document from 'admins' collection where document ID = adminId
        IF adminDoc does not exist THEN
            RETURN "Error: Unauthorized access"
        END IF
        
        TRY:
            IF action == 'view_all' THEN
                // Get all citizens
                citizens = QUERY 'citizens' collection ORDER BY createdAt DESCENDING
                RETURN citizens
                
            ELSE IF action == 'view_one' THEN
                // Get specific citizen
                citizenDoc = GET document from 'citizens' collection where document ID = citizenId
                IF citizenDoc does not exist THEN
                    RETURN "Error: Citizen not found"
                END IF
                RETURN citizenDoc.data()
                
            ELSE IF action == 'update' THEN
                // Update citizen data
                citizenDoc = GET document from 'citizens' collection where document ID = citizenId
                IF citizenDoc does not exist THEN
                    RETURN "Error: Citizen not found"
                END IF
                
                UPDATE citizenDoc with updateData
                RETURN "Success: Citizen updated successfully"
                
            ELSE IF action == 'delete' THEN
                // Delete citizen (soft delete - set isActive to false)
                citizenDoc = GET document from 'citizens' collection where document ID = citizenId
                IF citizenDoc does not exist THEN
                    RETURN "Error: Citizen not found"
                END IF
                
                UPDATE citizenDoc with { isActive: false }
                RETURN "Success: Citizen deactivated successfully"
                
            ELSE
                RETURN "Error: Invalid action"
            END IF
            
        CATCH Exception:
            RETURN "Error: Operation failed - " + error message
        END TRY
    END FUNCTION
```

---

## 12. Admin: Manage Drivers

**Table 12: Admin Manage Drivers Pseudo Code**

```
FUNCTION manageDrivers(adminId, action, driverId, updateData):
    BEGIN
        // Verify admin permissions
        adminDoc = GET document from 'admins' collection where document ID = adminId
        IF adminDoc does not exist THEN
            RETURN "Error: Unauthorized access"
        END IF
        
        TRY:
            IF action == 'view_all' THEN
                // Get all drivers
                drivers = QUERY 'drivers' collection ORDER BY createdAt DESCENDING
                RETURN drivers
                
            ELSE IF action == 'view_one' THEN
                // Get specific driver
                driverDoc = GET document from 'drivers' collection where document ID = driverId
                IF driverDoc does not exist THEN
                    RETURN "Error: Driver not found"
                END IF
                RETURN driverDoc.data()
                
            ELSE IF action == 'create' THEN
                // Create new driver
                newDriver = {
                    uid: generateUID(),
                    name: updateData.name,
                    email: updateData.email,
                    phone: updateData.phone,
                    role: 'driver',
                    licenseNumber: updateData.licenseNumber,
                    vehicleNumber: updateData.vehicleNumber,
                    isAvailable: true,
                    completedPickups: 0,
                    createdAt: currentTimestamp(),
                    isActive: true
                }
                SAVE newDriver to 'drivers' collection
                RETURN "Success: Driver created successfully"
                
            ELSE IF action == 'update' THEN
                // Update driver data
                driverDoc = GET document from 'drivers' collection where document ID = driverId
                IF driverDoc does not exist THEN
                    RETURN "Error: Driver not found"
                END IF
                
                UPDATE driverDoc with updateData
                RETURN "Success: Driver updated successfully"
                
            ELSE IF action == 'delete' THEN
                // Delete driver (soft delete)
                driverDoc = GET document from 'drivers' collection where document ID = driverId
                IF driverDoc does not exist THEN
                    RETURN "Error: Driver not found"
                END IF
                
                UPDATE driverDoc with { isActive: false, isAvailable: false }
                RETURN "Success: Driver deactivated successfully"
                
            ELSE
                RETURN "Error: Invalid action"
            END IF
            
        CATCH Exception:
            RETURN "Error: Operation failed - " + error message
        END TRY
    END FUNCTION
```

---

## 13. Admin: View Dashboard Statistics

**Table 13: Admin View Dashboard Statistics Pseudo Code**

```
FUNCTION viewDashboardStatistics(adminId):
    BEGIN
        // Verify admin permissions
        adminDoc = GET document from 'admins' collection where document ID = adminId
        IF adminDoc does not exist THEN
            RETURN "Error: Unauthorized access"
        END IF
        
        TRY:
            statistics = {}
            
            // Count total citizens
            citizensQuery = QUERY 'citizens' collection WHERE isActive == true
            statistics.totalCitizens = COUNT(citizensQuery)
            
            // Count total drivers
            driversQuery = QUERY 'drivers' collection WHERE isActive == true
            statistics.totalDrivers = COUNT(driversQuery)
            
            // Count total admins
            adminsQuery = QUERY 'admins' collection WHERE isActive == true
            statistics.totalAdmins = COUNT(adminsQuery)
            
            statistics.totalUsers = statistics.totalCitizens + statistics.totalDrivers + statistics.totalAdmins
            
            // Count pickup requests
            allPickupsQuery = QUERY 'pickupRequests' collection
            allPickups = EXECUTE allPickupsQuery
            
            statistics.totalPickups = COUNT(allPickups)
            statistics.pendingPickups = COUNT(allPickups WHERE status == 'pending')
            statistics.assignedPickups = COUNT(allPickups WHERE status == 'assigned')
            statistics.completedPickups = COUNT(allPickups WHERE status == 'completed')
            
            // Count reports
            allReportsQuery = QUERY 'reports' collection
            allReports = EXECUTE allReportsQuery
            
            statistics.totalReports = COUNT(allReports)
            statistics.openReports = COUNT(allReports WHERE status == 'open')
            statistics.resolvedReports = COUNT(allReports WHERE status == 'resolved')
            
            // Calculate completion rate
            IF statistics.totalPickups > 0 THEN
                statistics.completionRate = (statistics.completedPickups / statistics.totalPickups) * 100
            ELSE
                statistics.completionRate = 0
            END IF
            
            RETURN statistics
            
        CATCH Exception:
            RETURN "Error: Failed to fetch statistics - " + error message
        END TRY
    END FUNCTION
```

---

## 14. Admin: Resolve Report

**Table 14: Admin Resolve Report Pseudo Code**

```
FUNCTION resolveReport(reportId, adminId, resolutionNotes):
    BEGIN
        // Validate input
        IF reportId is empty OR adminId is empty THEN
            RETURN "Error: Invalid request"
        END IF
        
        IF resolutionNotes is empty THEN
            RETURN "Error: Please provide resolution notes"
        END IF
        
        // Verify admin permissions
        adminDoc = GET document from 'admins' collection where document ID = adminId
        IF adminDoc does not exist THEN
            RETURN "Error: Unauthorized access"
        END IF
        
        TRY:
            // Get report
            reportDoc = GET document from 'reports' collection where document ID = reportId
            
            IF reportDoc does not exist THEN
                RETURN "Error: Report not found"
            END IF
            
            reportData = reportDoc.data()
            
            // Check if report is already resolved
            IF reportData.status == 'resolved' THEN
                RETURN "Error: Report is already resolved"
            END IF
            
            // Update report
            UPDATE reportDoc with {
                status: 'resolved',
                resolvedAt: currentTimestamp(),
                assignedTo: adminId,
                resolutionNotes: resolutionNotes
            }
            
            // Create notification for reporter
            notification = {
                userId: reportData.reporterId,
                title: 'Report Resolved',
                message: 'Your reported issue has been resolved',
                type: 'report_resolved',
                relatedEntityId: reportId,
                relatedEntityType: 'report',
                isRead: false,
                createdAt: currentTimestamp()
            }
            SAVE notification to 'notifications' collection
            
            RETURN "Success: Report resolved successfully"
            
        CATCH Exception:
            RETURN "Error: Failed to resolve report - " + error message
        END TRY
    END FUNCTION
```

---

## Notes

- All functions use **Firebase Firestore** as the database
- All functions use **Firebase Authentication** for user management
- Error handling is included in all functions
- Notifications are created for important events
- Timestamps use Firestore's `Timestamp` type
- All collections are accessed through the `DatabaseService` class
- Real-time updates use Firestore streams where applicable

---

**End of Pseudo Codes Document**
