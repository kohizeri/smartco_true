# Appointment Scheduling System - Test Plan

## Test Cases

### 1. Vet Scheduling Tests

#### Test 1.1: Schedule with Valid Owner Email
- **Action**: Vet schedules appointment with valid owner email
- **Expected**: 
  - Appointment created with status "pending"
  - Stored in `users/{vetUid}/appointments/{appointmentId}`
  - Stored in `users/{ownerUid}/reminders/{reminderKey}`
  - Success message shown

#### Test 1.2: Schedule with Invalid Owner Email
- **Action**: Vet attempts to schedule with non-existent email
- **Expected**: 
  - Error message: "Owner email not found. Please verify the email address."
  - No appointment created

#### Test 1.3: Schedule Overlapping Appointment
- **Action**: Vet schedules appointment within 1 hour of existing confirmed appointment for same pet
- **Expected**: 
  - Error message showing existing appointment time
  - No appointment created

### 2. Owner Acceptance Tests

#### Test 2.1: Accept Pending Appointment
- **Action**: Owner clicks "Accept" on pending appointment
- **Expected**: 
  - Status changes to "confirmed" in both owner's reminders and vet's appointments
  - Success message: "Appointment accepted!"
  - UI updates to show green "Confirmed" badge
  - Accept/Reject/Reschedule buttons disappear

#### Test 2.2: View Confirmed Appointment
- **Action**: Owner views confirmed appointment
- **Expected**: 
  - Green border and badge
  - Only "Mark as done" button visible
  - No Accept/Reject/Reschedule buttons

### 3. Owner Rejection Tests

#### Test 3.1: Reject Without Reason
- **Action**: Owner clicks "Reject" but doesn't enter reason
- **Expected**: 
  - Warning message: "Please provide a reason"
  - Dialog stays open

#### Test 3.2: Reject With Reason
- **Action**: Owner clicks "Reject" and enters reason
- **Expected**: 
  - Status changes to "rejected" in both views
  - Rejection reason stored and displayed
  - Red "Rejected" badge shown
  - Rejection reason displayed in red box

### 4. Owner Reschedule Tests

#### Test 4.1: Reschedule to Valid Time
- **Action**: Owner clicks "Reschedule" and picks new date/time
- **Expected**: 
  - Date and time updated in both views
  - Status changes to "confirmed"
  - Original dateTime stored in "originalDateTime"
  - Success message: "Appointment rescheduled!"

#### Test 4.2: Reschedule to Overlapping Time
- **Action**: Owner tries to reschedule to time that overlaps with another confirmed appointment
- **Expected**: 
  - Error message showing conflicting appointment
  - Appointment not rescheduled

#### Test 4.3: Reschedule Without Selecting Time
- **Action**: Owner clicks "Reschedule" but doesn't select date/time
- **Expected**: 
  - Warning message: "Please select a date and time"
  - Dialog stays open

### 5. Real-time Sync Tests

#### Test 5.1: Status Update Sync
- **Action**: Owner accepts/rejects appointment
- **Expected**: 
  - Vet's view updates immediately without refresh
  - Status badge changes in real-time

#### Test 5.2: Reschedule Sync
- **Action**: Owner reschedules appointment
- **Expected**: 
  - New date/time appears in vet's view immediately
  - Status shows "Confirmed"

### 6. UI Display Tests

#### Test 6.1: Pending Appointment Display (Owner)
- **Expected**: 
  - Orange border (2px)
  - Orange "Pending" badge
  - Orange icon background
  - Accept/Reject/Reschedule buttons visible

#### Test 6.2: Pending Appointment Display (Vet)
- **Expected**: 
  - Orange border
  - Orange "Pending" badge
  - Orange icon background
  - No rejection reason shown

#### Test 6.3: Confirmed Appointment Display
- **Expected**: 
  - Green border
  - Green "Confirmed" badge
  - Green icon background
  - No action buttons (except mark complete)

#### Test 6.4: Rejected Appointment Display
- **Expected**: 
  - Red border
  - Red "Rejected" badge
  - Red icon background
  - Rejection reason displayed in red box (both views)

### 7. Data Validation Tests

#### Test 7.1: Required Fields Validation
- **Action**: Try to schedule without pet name, email, date, or time
- **Expected**: 
  - Error message: "Please fill all required fields"
  - No appointment created

#### Test 7.2: Email Format Validation
- **Action**: Enter valid email format but non-existent user
- **Expected**: 
  - Error message: "Owner email not found"

### 8. Edge Cases

#### Test 8.1: Multiple Pending Appointments
- **Action**: Vet schedules multiple appointments for same owner
- **Expected**: 
  - All show as pending
  - Owner can accept/reject each independently

#### Test 8.2: Complete Pending Appointment
- **Action**: Try to mark pending appointment as complete
- **Expected**: 
  - Only Accept/Reject/Reschedule buttons visible
  - No "Mark as done" button for pending appointments

#### Test 8.3: Edit Vet Appointment (Owner)
- **Action**: Owner tries to edit vet appointment
- **Expected**: 
  - Error message: "Vet appointments cannot be edited by owners."
  - No edit dialog opens

## Database Schema Verification

### Owner's Reminder Structure
```
users/{ownerUid}/reminders/{reminderKey}:
  - title: string
  - date: string (YYYY-MM-DD)
  - time: string (HH:mm)
  - dateTime: number (milliseconds)
  - notes: string
  - completed: boolean
  - petName: string
  - vetEmail: string
  - vetUid: string
  - appointmentId: string
  - createdAt: number
  - type: "appointment"
  - status: "pending" | "confirmed" | "rejected"
  - rejectionReason: string (optional)
  - originalDateTime: number (optional, for reschedule)
  - confirmedAt: number (optional)
  - rejectedAt: number (optional)
  - rescheduledAt: number (optional)
```

### Vet's Appointment Structure
```
users/{vetUid}/appointments/{appointmentId}:
  - petName: string
  - ownerEmail: string
  - ownerUid: string
  - dateTime: number
  - date: string
  - time: string
  - notes: string
  - completed: boolean
  - createdAt: number
  - reminderKey: string
  - status: "pending" | "confirmed" | "rejected"
  - rejectionReason: string (optional)
  - originalDateTime: number (optional)
  - confirmedAt: number (optional)
  - rejectedAt: number (optional)
  - rescheduledAt: number (optional)
  - completedAt: number (optional)
```

## Implementation Checklist

✅ Status field added to appointments
✅ Email validation implemented
✅ Overlap prevention implemented
✅ Accept functionality implemented
✅ Reject functionality with reason implemented
✅ Reschedule functionality implemented
✅ Two-way sync implemented
✅ UI badges for pending/confirmed/rejected
✅ Rejection reason display
✅ Action buttons for pending appointments
✅ Prevent editing vet appointments
✅ Real-time updates via Firebase listeners
