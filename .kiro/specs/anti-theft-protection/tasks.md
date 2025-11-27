# Implementation Plan

## Phase 1: Project Setup and Core Infrastructure

- [x] 1. Set up Flutter project structure and dependencies





  - [x] 1.1 Configure pubspec.yaml with required dependencies (flutter_secure_storage, geolocator, camera, workmanager, sqflite, crypto)


    - _Requirements: 10.4_

  - [x] 1.2 Create directory structure following Clean Architecture (lib/domain, lib/data, lib/presentation, lib/services)

    - _Requirements: 9.1_

  - [x] 1.3 Configure Android manifest with required permissions (DEVICE_ADMIN, ACCESSIBILITY, LOCATION, CAMERA, SMS, PHONE, BOOT_COMPLETED)

    - _Requirements: 1.3, 2.1, 5.1_

  - [x] 1.4 Disable Android backup in manifest for security

    - _Requirements: 22.1_

- [x] 2. Implement core data models






  - [x] 2.1 Create SecurityEvent model with all event types enum

    - _Requirements: 4.3_

  - [x] 2.2 Create LocationData model with Google Maps link generation

    - _Requirements: 5.3_

  - [x] 2.3 Create CapturedPhoto model with metadata

    - _Requirements: 4.5_
  - [x] 2.4 Create ProtectionConfig model with all settings


    - _Requirements: 9.2_
  - [x] 2.5 Create RemoteCommand model with parsing logic


    - _Requirements: 8.1_
  - [x] 2.6 Create SimInfo model for SIM card tracking


    - _Requirements: 13.1_




  - [x] 2.7 Create CallLogEntry model





    - _Requirements: 19.2_

  - [x] 2.8 Write property test for RemoteCommand parsing





    - **Property 8: SMS Command Parsing and Validation**
    - **Validates: Requirements 8.1, 8.4**

## Phase 2: Storage and Security Services

- [x] 3. Implement Storage Service



  - [x] 3.1 Create IStorageService interface

    - _Requirements: 15.1_
  - [x] 3.2 Implement SecureStorageService using flutter_secure_storage for sensitive data


    - _Requirements: 1.2, 22.2_

  - [x] 3.3 Implement SharedPreferencesStorage for non-sensitive configuration

    - _Requirements: 2.5_

  - [x] 3.4 Write unit tests for storage operations

    - _Requirements: 3.1, 3.2_
-

- [x] 4. Implement Security Log Service




  - [x] 4.1 Create ISecurityLogService interface


    - _Requirements: 4.3_

  - [x] 4.2 Implement SQLite database with encryption (sqlcipher) for security logs

    - _Requirements: 4.3, 19.3_

  - [x] 4.3 Implement log event creation with metadata (timestamp, location, type)

    - _Requirements: 4.1_

  - [x] 4.4 Implement log retrieval with filtering by type and date range

    - _Requirements: 9.4_

  - [x] 4.5 Implement automatic log rotation (keep last 1000 events)

    - _Requirements: 10.5_

  - [x] 4.6 Write property test for security event logging

    - **Property 4: Security Event Logging**
    - **Validates: Requirements 4.1, 4.3, 6.3, 11.5, 12.5, 17.3**
-

- [x] 5. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.

## Phase 3: Authentication System
- [x] 6. Implement Authentication Service


















- [ ] 6. Implement Authentication Service


  - [x] 6.1 Create IAuthenticationService interface

    - _Requirements: 1.1_

  - [x] 6.2 Implement password hashing with SHA-256 and random salt

    - _Requirements: 1.2_

  - [x] 6.3 Implement password strength validation (min 8 chars, letters and numbers)

    - _Requirements: 1.1_
  - [x] 6.4 Implement password verification logic

    - _Requirements: 1.4_

  - [x] 6.5 Implement failed attempt counter with threshold (3 attempts)


    - _Requirements: 1.5_

  - [x] 6.6 Implement counter reset on successful login





    - _Requirements: 1.6_
  - [x] 6.7 Write property test for password hashing consistency


    - **Property 1: Password Hashing Consistency**
    - **Validates: Requirements 1.2**

  - [x] 6.8 Write property test for failed attempt counter reset

    - **Property 2: Failed Attempt Counter Reset**
    - **Validates: Requirements 1.6**

## Phase 4: Location and Camera Services


- [x] 7. Implement Location Service


  - [x] 7.1 Create ILocationService interface


    - _Requirements: 5.1_
  - [x] 7.2 Implement location tracking using FusedLocationProvider


    - _Requirements: 5.2, 10.1_

  - [x] 7.3 Implement periodic location updates (every 5 minutes default)

    - _Requirements: 5.2_

  - [x] 7.4 Implement location history storage with timestamps

    - _Requirements: 5.3_

  - [x] 7.5 Implement high-frequency tracking mode (30 seconds for panic mode)

    - _Requirements: 21.4_
  - [x] 7.6 Implement background tracking using WorkManager


    - _Requirements: 5.5, 10.4_
  - [x] 7.7 Implement adaptive tracking frequency based on battery level

    - _Requirements: 10.3_
  - [x] 7.8 Write property test for location tracking persistence


    - **Property 6: Location Tracking Persistence**
    - **Validates: Requirements 5.3**
-

- [x] 8. Implement Camera Service




  - [x] 8.1 Create ICameraService interface


    - _Requirements: 4.2_

  - [x] 8.2 Implement silent front camera capture (no preview, no shutter sound)

    - _Requirements: 4.2, 17.2_

  - [x] 8.3 Implement photo storage with encryption in app private directory

    - _Requirements: 4.5_

  - [x] 8.4 Implement photo metadata association (timestamp, location, reason)
    - _Requirements: 4.5_
  - [x] 8.5 Implement automatic cleanup of old photos (30+ days)
    - _Requirements: 10.5_
  - [x] 8.6 Write property test for photo capture storage


    - **Property 5: Photo Capture Storage**
    - **Validates: Requirements 4.5, 13.5, 23.5**

- [x] 9. Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.

## Phase 5: Native Android Services
-

- [x] 10. Implement Device Admin Service (Native Android)




  - [x] 10.1 Create DeviceAdminReceiver in Kotlin

    - _Requirements: 2.1_


  - [x] 10.2 Implement onDisableRequested to intercept deactivation attempts







    - _Requirements: 2.2_

  - [x] 10.3 Implement device lock functionality

    - _Requirements: 8.1_

  - [x] 10.4 Implement factory reset (wipe) functionality

    - _Requirements: 8.3_
  - [x] 10.5 Create Flutter method channel for Device Admin operations

    - _Requirements: 1.3_
  - [x] 10.6 Implement 30-second deactivation window after password entry


    - _Requirements: 2.3_

- [x] 11. Implement Accessibility Service (Native Android)




  - [x] 11.1 Create AccessibilityService in Kotlin


    - _Requirements: 1.3_
  - [x] 11.2 Implement app launch detection and blocking (Settings, file managers)

    - _Requirements: 12.2, 23.2_
  - [x] 11.3 Implement power menu detection and blocking

    - _Requirements: 11.2_
  - [x] 11.4 Implement password overlay display

    - _Requirements: 2.2, 11.2_
  - [x] 11.5 Create Flutter method channel for Accessibility Service


    - _Requirements: 3.1_
  - [x] 11.6 Implement Quick Settings panel blocking

    - _Requirements: 12.3, 27.3_
-

- [x] 12. Implement Boot and Auto-Restart Services


  - [x] 12.1 Create BOOT_COMPLETED BroadcastReceiver


    - _Requirements: 2.5_

  - [x] 12.2 Implement Protected Mode state restoration on boot

    - _Requirements: 2.5_

  - [x] 12.3 Implement auto-restart using JobScheduler (within 3 seconds)
    - _Requirements: 2.4_

  - [x] 12.4 Implement force-stop detection and logging
    - _Requirements: 2.6_
  - [x] 12.5 Implement Safe Mode detection on boot

    - _Requirements: 20.1_

## Phase 6: SMS and Remote Control


- [x] 13. Implement SMS Service




  - [x] 13.1 Create ISmsService interface

    - _Requirements: 8.1_

  - [x] 13.2 Implement SMS BroadcastReceiver for incoming messages

    - _Requirements: 8.1_

  - [x] 13.3 Implement command parsing (LOCK#, WIPE#, LOCATE#, ALARM#)

    - _Requirements: 8.1, 8.3, 8.4, 8.5_

  - [x] 13.4 Implement Emergency Contact validation

    - _Requirements: 8.6_

  - [x] 13.5 Implement password verification for commands
    - _Requirements: 8.7_

  - [x] 13.6 Implement SMS sending with delivery confirmation
    - _Requirements: 8.4_
  - [x] 13.7 Implement location response with Google Maps link
    - _Requirements: 8.4_
  - [x] 13.8 Write property test for non-emergency contact rejection


    - **Property 9: Non-Emergency Contact Command Rejection**
    - **Validates: Requirements 8.6**

  - [x] 13.9 Write property test for incorrect password rejection
    - **Property 10: Incorrect Password Command Rejection**
    - **Validates: Requirements 8.7**
- [x] 14. Implement Remote Command Execution












- [ ] 14. Implement Remote Command Execution

  - [x] 14.1 Implement LOCK command (lock device + enable Kiosk Mode)


    - _Requirements: 8.1, 8.2_

  - [x] 14.2 Implement WIPE command (factory reset via Device Admin)

    - _Requirements: 8.3_

  - [x] 14.3 Implement LOCATE command (reply with GPS + Maps link)

    - _Requirements: 8.4_


  - [x] 14.4 Implement ALARM command (2-minute max volume alarm)



    - _Requirements: 8.5_


  - [x] 14.5 Implement custom lock screen message display

    - _Requirements: 8.2_


- [x] 15. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.

## -hase 7: Protection Service and Mon
itoring
- [x] 16. Implement Protection Service














- [ ] 16. Implement Protection Service

  - [x] 16.1 Create IProtectionService interface


    - _Requirements: 1.3_
  - [x] 16.2 Implement Protected Mode enable/disable with state persistence


    - _Requirements: 1.3, 1.4_
  - [x] 16.3 Implement Kiosk Mode using Task Locking


    - _Requirements: 3.1, 3.2_
  - [x] 16.4 Implement Panic Mode activation (volume down x5)


    - _Requirements: 21.1, 21.2_
  - [x] 16.5 Implement Stealth Mode (hide from recent apps, optional icon hiding)


    - _Requirements: 18.1, 18.3_
  - [x] 16.6 Implement dialer code access (*#123456#)


    - _Requirements: 18.4, 18.5_
  - [x] 16.7 Write property test for configuration change protection



    - **Property 3: Configuration Change Protection**
    - **Validates: Requirements 1.4, 9.3**

- [x] 17. Implement Monitoring Service




  - [x] 17.1 Create IMonitoringService interface

    - _Requirements: 6.1_
  - [x] 17.2 Implement Airplane Mode monitoring and auto-disable


    - _Requirements: 6.1, 6.2_

  - [x] 17.3 Implement SIM card change detection (within 5 seconds)

    - _Requirements: 13.2_

  - [x] 17.4 Implement screen unlock attempt monitoring

    - _Requirements: 17.1, 17.2_


  - [x] 17.5 Implement call monitoring (incoming/outgoing)
    - _Requirements: 19.1, 19.2_

  - [x] 17.6 Implement USB debugging detection

    - _Requirements: 22.4_
  - [x] 17.7 Implement developer options access detection


    - _Requirements: 22.5_

  - [x] 17.8 Write property test for SIM change detection and alert

    - **Property 11: SIM Change Detection and Alert**
    - **Validates: Requirements 13.3, 13.5**
  - [x] 17.9 Write property test for call logging completeness

  - [x] 17.9 Write property test for call logging completeness
    - **Property 14: Call Logging Completeness**
    - **Validates: Requirements 19.2, 19.3**

## Phase 8: Alarm and Alert System

- [x] 18. Implement Alarm Service


  - [x] 18.1 Implement loud alarm sound at maximum volume


    - _Requirements: 7.1_

  - [x] 18.2 Implement alarm persistence (ignore volume settings)

    - _Requirements: 7.4_


  - [x] 18.3 Implement alarm stop on correct password



    - _Requirements: 7.5_
  - [x] 18.4 Implement continuous alarm until password entry
    - _Requirements: 7.2_
  - [x] 18.5 Write property test for alarm trigger on unauthorized access


    - **Property 7: Alarm Trigger on Unauthorized Access**
    - **Validates: Requirements 7.1**
-

- [x] 19. Implement Alert and Notification Service


  - [x] 19.1 Implement suspicious activity notifications


    - _Requirements: 7.3_

  - [x] 19.2 Implement SMS alerts to Emergency Contact

    - _Requirements: 13.3, 17.4_


  - [x] 19.3 Implement photo capture on security events

  - [x] 19.4 Implement hidden notification for background service

  - [x] 19.4 Implement hidden notification for background service

    - _Requirements: 18.2_

- [x] 20. Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.

## Phase 9: Advanced Protection Features

- [x] 21. Implement Settings and App Blocking




  - [x] 21.1 Implement complete Settings app blocking


    - _Requirements: 12.1, 27.1_

  - [x] 21.2 Implement file manager app blocking with password overlay

    - _Requirements: 23.1, 23.2_

  - [x] 21.3 Implement 1-minute file manager access timeout

    - _Requirements: 23.3, 23.4_
  - [x] 21.4 Implement screen lock change blocking


    - _Requirements: 30.1, 30.2_

  - [x] 21.5 Implement account addition blocking

    - _Requirements: 31.1, 31.2_

  - [x] 21.6 Implement app installation/uninstallation blocking

    - _Requirements: 32.1, 32.2, 32.3_


  - [x] 21.7 Implement factory reset blocking from Settings
    - _Requirements: 33.1_
  - [x] 21.8 Write property test for USB data transfer blocking


    - **Property 16: USB Data Transfer Blocking**
    - **Validates: Requirements 28.3**
  - [x] 21.9 Write property test for screen lock change blocking


    - **Property 18: Screen Lock Change Blocking**
    - **Validates: Requirements 30.2**
  - [x] 21.10 Write property test for account addition blocking

    - **Property 19: Account Addition Blocking**
    - **Validates: Requirements 31.2**
  - [x] 21.11 Write property test for app installation blocking

    - **Property 20: App Installation/Uninstallation Blocking**
    - **Validates: Requirements 32.2, 32.3**
-

- [x] 22. Implement USB and Trusted Devices


  - [x] 22.1 Implement USB connection detection


    - _Requirements: 28.1_

  - [x] 22.2 Implement trusted computer list storage (encrypted)

    - _Requirements: 29.1_

  - [x] 22.3 Implement USB data transfer blocking for untrusted computers

    - _Requirements: 28.3_


  - [x] 22.4 Implement trusted device addition with password
    - _Requirements: 28.4_

  - [x] 22.5 Implement trusted devices persistence across reboots

    - _Requirements: 29.2_

  - [x] 22.6 Write property test for trusted devices persistence


    - **Property 17: Trusted Devices Persistence**
    - **Validates: Requirements 29.1, 29.2**

## Phase 10: WhatsApp and Cloud Integration

- [x] 23. Implement WhatsApp Location Sharing




  - [x] 23.1 Implement WhatsApp message sending via Intent/API


    - _Requirements: 26.1_


  - [x] 23.2 Implement location message format (GPS, Maps link, battery, timestamp)

    - _Requirements: 26.2_
  - [x] 23.3 Implement periodic location updates (every 15 minutes)

    - _Requirements: 26.1_

  - [x] 23.4 Implement significant location change detection (100m threshold)

    - _Requirements: 26.3_

  - [x] 23.5 Implement SMS fallback when WhatsApp unavailable

    - _Requirements: 26.4_

  - [x] 23.6 Implement increased frequency in panic mode (every 2 minutes)

    - _Requirements: 26.5_

  - [x] 23.7 Write property test for WhatsApp location message format

    - **Property 15: WhatsApp Location Message Format**
    - **Validates: Requirements 26.2**
- [x] 24. Implement Cloud Photo Upload




- [ ] 24. Implement Cloud Photo Upload


  - [x] 24.1 Implement cloud storage upload for intruder photos

    - _Requirements: 35.1_

  - [x] 24.2 Implement upload link sharing via WhatsApp and SMS

    - _Requirements: 35.2_

  - [x] 24.3 Implement offline queue for uploads

    - _Requirements: 35.3_

  - [x] 24.4 Implement retry logic with exponential backoff (5 retries)

    - _Requirements: 35.5_

  - [x] 24.5 Write property test for cloud photo upload and notification

    - **Property 22: Cloud Photo Upload and Notification**
    - **Validates: Requirements 35.1, 35.2**
- [x] 25. Checkpoint - Ensure all tests pass








- [ ] 25. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 11: Backup, Restore, and Reporting

- [x] 26. Implement Backup and Restore Service

  - [x] 26.1 Implement settings and logs export as encrypted file


    - _Requirements: 15.1_

  - [x] 26.2 Implement backup encryption using Master Password

    - _Requirements: 15.2_
  - [x] 26.3 Implement backup restore with password decryption

    - _Requirements: 15.3_

  - [x] 26.4 Implement all settings and logs import
    - _Requirements: 15.4_
  - [x] 26.5 Implement 3-attempt limit for incorrect backup password
    - _Requirements: 15.5_
  - [x] 26.6 Write property test for backup encryption round-trip



    - **Property 12: Backup Encryption Round-Trip**
    - **Validates: Requirements 15.2, 15.4**
-

- [x] 27. Implement Daily Status Report


  - [x] 27.1 Implement configurable report time


    - _Requirements: 25.1_

  - [x] 27.2 Implement report generation (status, battery, location, events count)

    - _Requirements: 25.2_

  - [x] 27.3 Implement SMS report sending to Emergency Contact

    - _Requirements: 25.3_
  - [x] 27.4 Implement "All OK" simple message when no events
    - _Requirements: 25.4_

  - [x] 27.5 Implement low battery warning in report
    - _Requirements: 25.5_
  - [x] 27.6 Write property test for status report completeness


    - **Property 23: Status Report Completeness**
    - **Validates: Requirements 25.2**
- [x] 28. Implement Audio Recording (Optional)




- [ ] 28. Implement Audio Recording (Optional)

  - [x] 28.1 Implement 30-second audio recording on suspicious activity


    - _Requirements: 34.1_
  - [x] 28.2 Implement encrypted audio storage with event details


    - _Requirements: 34.2_
  - [x] 28.3 Implement continuous recording in panic mode



    - _Requirements: 34.3_
  - [x] 28.4 Implement audio playback in security logs

    - _Requirements: 34.4_
  - [x] 28.5 Write property test for audio recording storage


    - **Property 21: Audio Recording Storage**
    - **Validates: Requirements 34.2**

## Phase 12: User Interface

- [x] 29. Implement Main Dashboard UI






  - [x] 29.1 Create main dashboard with protection status display


    - _Requirements: 9.1_

  - [x] 29.2 Implement toggle switches for all protection features
    - _Requirements: 9.2_
  - [x] 29.3 Implement Arabic labels and RTL support

    - _Requirements: 9.5_
  - [x] 29.4 Implement password confirmation dialog for setting changes

    - _Requirements: 9.3_

- [x] 30. Implement Security Logs UI





  - [x] 30.1 Create security logs list view with chronological order


    - _Requirements: 9.4_

  - [x] 30.2 Implement filtering options (by type, date)

    - _Requirements: 9.4_

  - [x] 30.3 Implement unauthorized access attempts display

    - _Requirements: 4.4_

  - [x] 30.4 Implement photo viewer for captured photos


    - _Requirements: 4.4_
  - [x] 30.5 Implement call logs display with Emergency Contact highlighting

    - _Requirements: 19.4, 19.5_

- [x] 31. Implement Location History UI





  - [x] 31.1 Create map view for location history

    - _Requirements: 5.4_

  - [x] 31.2 Implement location markers with timestamps

    - _Requirements: 5.4_

- [x] 32. Implement Setup and Configuration UI



  - [x] 32.1 Create first-run password setup screen


    - _Requirements: 1.1_

  - [x] 32.2 Create Emergency Contact setup screen with validation

    - _Requirements: 16.1, 16.2_
  - [x] 32.3 Implement verification SMS flow for Emergency Contact change

    - _Requirements: 16.3, 16.4_

  - [x] 32.4 Create auto-protection schedule configuration

    - _Requirements: 14.1_
  - [x] 32.5 Create trusted WiFi (home) configuration
    - _Requirements: 14.3_
  - [x] 32.6 Create trusted computers management screen
    - _Requirements: 28.4, 29.4_
  - [x] 32.7 Write property test for phone number validation



    - **Property 13: Phone Number Validation and Storage**
    - **Validates: Requirements 16.2**

- [x] 33. Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.



## Phase 13: Test Mode and Final Integration

- [x] 34. Implement Test Mode



  - [x] 34.1 Create test mode UI with test buttons for all features

    - _Requirements: 24.1_

  - [x] 34.2 Implement alarm test (5 seconds, no SMS)

    - _Requirements: 24.2_

  - [x] 34.3 Implement camera test (display photo, no logging)

    - _Requirements: 24.3_
  - [x] 34.4 Implement SMS command simulation


    - _Requirements: 24.4_
  - [x] 34.5 Implement test results report display


    - _Requirements: 24.5_

  - [x] 34.6 Implement detailed error messages for failed tests

    - _Requirements: 24.6_

- [x] 35. Implement Kiosk Mode UI




  - [x] 35.1 Create custom lock screen for Kiosk Mode


    - _Requirements: 3.5_
  - [x] 35.2 Implement password entry in Kiosk Mode


    - _Requirements: 3.4_
  - [x] 35.3 Create fake "Device Locked by Administrator" screen for panic mode


    - _Requirements: 21.3_

- [x] 36. Final Integration and Polish





  - [x] 36.1 Wire all services together with dependency injection


    - _Requirements: All_
  - [x] 36.2 Implement foreground service for persistent monitoring


    - _Requirements: 2.4, 5.5_
  - [x] 36.3 Implement battery optimization exemption request


    - _Requirements: 10.1_
  - [x] 36.4 Implement memory footprint optimization (under 50MB)


    - _Requirements: 10.5_
  - [x] 36.5 Implement code obfuscation for release build


    - _Requirements: 22.1_




- [-] 37. Final Checkpoint - Ensure all tests pass


  - Ensure all tests pass, ask the user if questions arise.
