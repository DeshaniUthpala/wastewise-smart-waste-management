# WasteWise - Data Design

## 3.4 Data Design

The WasteWise application's data design organizes the primary entities: **Citizen**, **Driver**, **Admin**, and **PickupRequest**. It defines relationships for efficient data storage and retrieval. Citizens are linked to pickup requests they create and view, while drivers are assigned to pickup requests they need to complete. Admins manage all entities including citizens, drivers, and pickup requests. This structure supports streamlined waste management operations, request tracking, and administrative oversight. **Firebase Firestore** is the primary backend, handling pickup requests, user authentication, real-time updates, and data synchronization across all user roles.

## Entities and Attributes

### 1. Citizen
- `UserId PK`: Integer (Primary Key)
- `Username`: String
- `Email`: String
- `Password`: String
- `Address`: String
- `RewardPoints`: Integer

### 2. PickupRequest
- `RequestId PK`: Integer (Primary Key)
- `WasteType`: String
- `Status`: String
- `Location`: String
- `RequestedDate`: DateTime
- `SpecialInstructions`: String
- `EstimatedWeight`: Double

### 3. Driver
- `UserId PK`: Integer (Primary Key)
- `Username`: String
- `Email`: String
- `Password`: String
- `LicenseNumber`: String
- `VehicleNumber`: String
- `IsAvailable`: Boolean

### 4. Admin
- `UserId PK`: Integer (Primary Key)
- `Username`: String
- `Email`: String
- `Password`: String

## Relationships

### Citizen -- Views -- PickupRequest
- This is a **many-to-many** relationship. A Citizen can "Views" multiple PickupRequests, and a PickupRequest can be "Views" by multiple Citizens. This is indicated by crow's foot symbols on both ends of the connecting line.

### Citizen -- Creates -- PickupRequest
- This is a **one-to-many** relationship. A Citizen "Creates" multiple PickupRequests, but each PickupRequest is "Creates" by only one Citizen. This is indicated by a single line on the Citizen side and a crow's foot symbol on the PickupRequest side.

### Driver -- Assigned To -- PickupRequest
- This is a **one-to-many** relationship. A Driver "Assigned To" multiple PickupRequests, but each PickupRequest is "Assigned To" by only one Driver. This is indicated by a single line on the Driver side and a crow's foot symbol on the PickupRequest side.

### Admin -- Manages -- Citizen
- This is a **one-to-many** relationship. An Admin "Manages" multiple Citizens, but each Citizen is "Manages" by only one Admin (or admin system). This is indicated by a single line on the Admin side and a crow's foot symbol on the Citizen side.

### Admin -- Manages -- Driver
- This is a **one-to-many** relationship. An Admin "Manages" multiple Drivers, but each Driver is "Manages" by only one Admin (or admin system). This is indicated by a single line on the Admin side and a crow's foot symbol on the Driver side.

### Admin -- Manages -- PickupRequest
- This is a **one-to-many** relationship. An Admin "Manages" multiple PickupRequests, but each PickupRequest is "Manages" by only one Admin (or admin system). This is indicated by a single line on the Admin side and a crow's foot symbol on the PickupRequest side.
