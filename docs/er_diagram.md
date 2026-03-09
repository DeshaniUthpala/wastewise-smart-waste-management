# WasteWise - Entity Relationship Diagram (Conceptual)

## Entity Relationships Overview

```
┌─────────────────┐
│   UserModel     │ (Base Class)
│  (Abstract)     │
└────────┬────────┘
         │
         ├──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  CitizenModel   │ │  DriverModel    │ │   AdminModel    │
│                 │ │                 │ │                 │
│ - rewardPoints  │ │ - vehicleId     │ │ (inherits base) │
│ - address       │ │ - licenseNumber │ │                 │
│ - location      │ │ - isAvailable  │ │                 │
│ - preferences   │ │ - currentRoute  │ │                 │
└────────┬────────┘ │ - rating        │ └─────────────────┘
         │          │ - location      │
         │          └────────┬────────┘
         │                   │
         │                   │
         ▼                   ▼
┌─────────────────────────────────────────┐
│         PickupRequestModel              │
│  - citizenId (FK → Citizen)            │
│  - driverId (FK → Driver)              │
│  - location                            │
│  - wasteType                            │
│  - status                               │
└────────┬───────────────────────────────┘
         │
         ├──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  ScheduleModel  │ │   TaskModel     │ │   RouteModel    │
│                 │ │                 │ │                 │
│ - citizenId     │ │ - requestId     │ │ - driverId      │
│ - driverId      │ │ - driverId      │ │ - waypoints     │
│ - routeId       │ │ - status        │ │ - pickupIds[]   │
│ - isCommon      │ │                 │ │ - status        │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │
         │
         ▼
┌─────────────────┐
│  ReportModel    │
│                 │
│ - reporterId    │
│ - assignedTo    │
│ - status        │
└─────────────────┘

┌─────────────────┐
│ VehicleModel    │
│                 │
│ - assignedDriver│
│ - capacity      │
└─────────────────┘

┌─────────────────┐
│NotificationModel│
│                 │
│ - userId        │
│ - relatedEntity │
└─────────────────┘

┌─────────────────┐
│ WasteTypeModel  │
│                 │
│ - category      │
│ - instructions  │
└─────────────────┘

┌─────────────────┐
│StatisticsModel  │
│                 │
│ - aggregates    │
│   all data      │
└─────────────────┘
```

## Relationship Cardinalities

| Relationship | Type | Cardinality |
|-------------|------|-------------|
| Citizen → PickupRequest | One-to-Many | 1 : N |
| Driver → PickupRequest | One-to-Many | 1 : N |
| Driver → Route | One-to-Many | 1 : N |
| Driver → Task | One-to-Many | 1 : N |
| Driver → Vehicle | Many-to-One | N : 1 |
| PickupRequest → Task | One-to-One | 1 : 1 |
| Route → PickupRequest | One-to-Many | 1 : N |
| Citizen → Report | One-to-Many | 1 : N |
| Citizen → Notification | One-to-Many | 1 : N |
| Citizen → Schedule | One-to-Many | 1 : N (if personal) |
| Schedule → Route | Many-to-One | N : 1 |

## Key Foreign Keys

- `PickupRequest.citizenId` → `Citizen.uid`
- `PickupRequest.driverId` → `Driver.uid`
- `Task.requestId` → `PickupRequest.id`
- `Task.driverId` → `Driver.uid`
- `Route.driverId` → `Driver.uid`
- `Route.pickupRequestIds[]` → `PickupRequest.id`
- `Schedule.driverId` → `Driver.uid`
- `Schedule.citizenId` → `Citizen.uid`
- `Schedule.routeId` → `Route.id`
- `Report.reporterId` → `Citizen.uid`
- `Vehicle.assignedDriverId` → `Driver.uid`
- `Notification.userId` → `User.uid` (any role)
