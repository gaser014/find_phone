# Requirements Document

## Introduction

تطبيق حماية شخصي من السرقة لأجهزة Android يوفر أقصى درجات الحماية للاستخدام الشخصي. التطبيق يستخدم صلاحيات Device Administrator وصلاحيات النظام المتقدمة لتوفير حماية قصوى تمنع اللصوص من استخدام الجهاز أو تعطيل الحماية. التطبيق مصمم للتثبيت اليدوي (sideloading) وليس للنشر على المتاجر الرسمية.

## Glossary

- **Anti-Theft App**: التطبيق الرئيسي لحماية الجهاز من السرقة
- **Device Administrator**: صلاحية نظام Android تسمح للتطبيق بالتحكم في بعض وظائف الجهاز الحرجة مثل قفل الشاشة ومسح البيانات
- **Accessibility Service**: خدمة إمكانية الوصول التي تسمح بمراقبة والتفاعل مع واجهة المستخدم
- **Kiosk Mode**: وضع يقفل الجهاز على تطبيق واحد فقط ويمنع الخروج منه باستخدام Task Locking
- **Master Password**: كلمة المرور الرئيسية للتطبيق المشفرة باستخدام SHA-256
- **Protected Mode**: الوضع المحمي الذي يفعل فيه جميع قيود الحماية والمراقبة
- **Location Tracking**: تتبع موقع الجهاز GPS باستخدام FusedLocationProvider
- **Remote Command**: أوامر SMS يمكن إرسالها للجهاز عن بعد بصيغة محددة
- **Airplane Mode**: وضع الطيران في Android الذي يعطل جميع الاتصالات اللاسلكية
- **Settings Access**: الوصول لإعدادات النظام Android Settings
- **Security Log**: سجل مشفر يحفظ جميع الأحداث الأمنية مع التفاصيل
- **Emergency Contact**: رقم هاتف موثوق يستقبل تنبيهات SMS عند الأحداث الحرجة
- **Trusted Location**: موقع WiFi محفوظ (مثل المنزل) يمكن تعطيل الحماية فيه تلقائياً
- **SIM Identifier**: معرف فريد لشريحة SIM يتضمن ICCID و IMSI
- **WhatsApp Location Sharing**: إرسال الموقع تلقائياً عبر WhatsApp API أو Intent
- **Trusted Computer**: جهاز كمبيوتر تم التحقق منه وحفظه للسماح بنقل البيانات عبر USB
- **USB Data Transfer**: نقل البيانات عبر كابل USB بما في ذلك MTP و PTP و ADB
- **Quick Settings Panel**: لوحة الإعدادات السريعة التي تظهر عند السحب من أعلى الشاشة

## Requirements

### Requirement 1

**User Story:** كمستخدم للتطبيق، أريد تفعيل وضع الحماية بكلمة مرور، حتى أحمي جهازي من الاستخدام غير المصرح به

#### Acceptance Criteria

1. WHEN a user opens the app for the first time THEN the Anti-Theft App SHALL prompt the user to create a Master Password with minimum 8 characters including letters and numbers
2. WHEN a user enters a Master Password THEN the Anti-Theft App SHALL validate the password strength and store it securely using SHA-256 hashing with salt
3. WHEN a user enables Protected Mode THEN the Anti-Theft App SHALL request and activate Device Administrator permissions and Accessibility Service
4. WHEN Protected Mode is active THEN the Anti-Theft App SHALL require Master Password for any configuration changes or app exit
5. WHEN a user enters incorrect Master Password three times consecutively THEN the Anti-Theft App SHALL trigger security alert, capture front camera photo, record location, and send SMS to Emergency Contact
6. WHEN a user successfully enters Master Password after failed attempts THEN the Anti-Theft App SHALL reset the failed attempt counter to zero

### Requirement 2

**User Story:** كمستخدم، أريد منع إلغاء تفعيل صلاحيات التطبيق، حتى لا يستطيع اللص تعطيل الحماية

#### Acceptance Criteria

1. WHEN the Anti-Theft App is activated as Device Administrator THEN the Anti-Theft App SHALL prevent uninstallation through standard Android uninstall process
2. WHEN a user attempts to deactivate Device Administrator from Settings THEN the Anti-Theft App SHALL intercept the request and display full-screen password prompt
3. WHEN correct Master Password is entered for deactivation THEN the Anti-Theft App SHALL allow Device Administrator deactivation for 30 seconds only
4. WHEN an unauthorized user tries to force-stop the app from Settings THEN the Anti-Theft App SHALL detect the stop and restart automatically within 3 seconds using JobScheduler
5. WHEN the device boots up THEN the Anti-Theft App SHALL start automatically via BOOT_COMPLETED receiver and restore Protected Mode state from encrypted storage
6. WHEN the app is restarted after force-stop THEN the Anti-Theft App SHALL log the event as suspicious activity with timestamp and trigger alarm

### Requirement 3

**User Story:** كمستخدم، أريد قفل الجهاز في وضع Kiosk Mode، حتى لا يستطيع اللص الوصول لأي تطبيقات أخرى أو الإعدادات

#### Acceptance Criteria

1. WHEN a user enables Kiosk Mode THEN the Anti-Theft App SHALL lock the device to show only the Anti-Theft App interface
2. WHEN Kiosk Mode is active THEN the Anti-Theft App SHALL block access to home button, recent apps, and notification panel
3. WHEN Kiosk Mode is active THEN the Anti-Theft App SHALL prevent access to device Settings
4. WHEN a user enters correct Master Password in Kiosk Mode THEN the Anti-Theft App SHALL exit Kiosk Mode and restore normal device operation
5. WHEN Kiosk Mode is active and device is locked THEN the Anti-Theft App SHALL show custom lock screen requiring Master Password

### Requirement 4

**User Story:** كمستخدم، أريد مراقبة محاولات الوصول غير المصرح بها، حتى أعرف إذا كان هناك محاولة سرقة

#### Acceptance Criteria

1. WHEN an incorrect Master Password is entered THEN the Anti-Theft App SHALL log the attempt with timestamp and location
2. WHEN three incorrect password attempts occur THEN the Anti-Theft App SHALL capture photo using front camera
3. WHEN unauthorized access is detected THEN the Anti-Theft App SHALL record the event in secure log storage
4. WHEN the user opens the app with correct password THEN the Anti-Theft App SHALL display all unauthorized access attempts
5. WHEN a photo is captured THEN the Anti-Theft App SHALL store it securely with associated attempt details

### Requirement 5

**User Story:** كمستخدم، أريد تتبع موقع جهازي، حتى أستطيع إيجاده إذا تمت سرقته

#### Acceptance Criteria

1. WHEN Protected Mode is enabled THEN the Anti-Theft App SHALL request location permissions
2. WHEN location permissions are granted THEN the Anti-Theft App SHALL track device location every 5 minutes
3. WHEN the device location changes THEN the Anti-Theft App SHALL store the new location with timestamp
4. WHEN the user views location history THEN the Anti-Theft App SHALL display all tracked locations on a map
5. WHEN location tracking is active THEN the Anti-Theft App SHALL continue tracking even when app is in background

### Requirement 6

**User Story:** كمستخدم، أريد التحكم الكامل في وضع الطيران، حتى أمنع اللص من تعطيل الاتصال

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor Airplane Mode status changes continuously
2. WHEN Airplane Mode is enabled without Master Password THEN the Anti-Theft App SHALL attempt to disable it automatically within 2 seconds
3. WHEN Airplane Mode toggle is detected THEN the Anti-Theft App SHALL log the event and trigger security alert
4. WHEN unauthorized Airplane Mode activation occurs THEN the Anti-Theft App SHALL display full-screen warning and request Master Password
5. WHEN the user enables Airplane Mode through the app with Master Password THEN the Anti-Theft App SHALL allow the change and log it as authorized

### Requirement 7

**User Story:** كمستخدم، أريد تلقي تنبيهات عن الأحداث المشبوهة، حتى أتصرف بسرعة في حالة السرقة

#### Acceptance Criteria

1. WHEN an unauthorized access attempt occurs THEN the Anti-Theft App SHALL trigger loud alarm sound
2. WHEN alarm is triggered THEN the Anti-Theft App SHALL continue playing alarm until Master Password is entered
3. WHEN suspicious activity is detected THEN the Anti-Theft App SHALL send notification with event details
4. WHEN alarm is playing THEN the Anti-Theft App SHALL ignore volume settings and play at maximum volume
5. WHEN Master Password is entered correctly THEN the Anti-Theft App SHALL stop alarm immediately

### Requirement 8

**User Story:** كمستخدم، أريد التحكم في الجهاز عن بعد، حتى أحمي بياناتي وأتتبع الجهاز إذا فقدته

#### Acceptance Criteria

1. WHEN the user sends SMS with format "LOCK#password" from Emergency Contact THEN the Anti-Theft App SHALL verify password, lock the device immediately, and enable Kiosk Mode
2. WHEN remote lock is activated THEN the Anti-Theft App SHALL display custom full-screen message with owner contact information and instructions
3. WHEN the user sends SMS with format "WIPE#password" from Emergency Contact THEN the Anti-Theft App SHALL verify password and erase all user data using Device Administrator factory reset
4. WHEN the user sends SMS with format "LOCATE#password" from Emergency Contact THEN the Anti-Theft App SHALL reply with current GPS coordinates, accuracy, timestamp, and Google Maps link
5. WHEN the user sends SMS with format "ALARM#password" from Emergency Contact THEN the Anti-Theft App SHALL trigger maximum volume alarm for 2 minutes even if device is on silent or vibrate
6. WHEN any Remote Command is received from non-Emergency Contact number THEN the Anti-Theft App SHALL ignore the command and log it as suspicious activity
7. WHEN Remote Command password is incorrect THEN the Anti-Theft App SHALL not execute command and send SMS reply indicating authentication failure

### Requirement 9

**User Story:** كمستخدم، أريد واجهة بسيطة وواضحة، حتى أستطيع إدارة إعدادات الحماية بسهولة

#### Acceptance Criteria

1. WHEN the user opens the app THEN the Anti-Theft App SHALL display main dashboard with protection status
2. WHEN the user views dashboard THEN the Anti-Theft App SHALL show toggle switches for all protection features
3. WHEN the user changes any setting THEN the Anti-Theft App SHALL require Master Password confirmation
4. WHEN the user views security logs THEN the Anti-Theft App SHALL display events in chronological order with filtering options
5. WHEN the user navigates the app THEN the Anti-Theft App SHALL provide clear Arabic labels and instructions

### Requirement 10

**User Story:** كمطور، أريد التطبيق يعمل بكفاءة في الخلفية، حتى لا يستهلك البطارية بشكل كبير

#### Acceptance Criteria

1. WHEN the app runs in background THEN the Anti-Theft App SHALL use battery-efficient location tracking methods
2. WHEN monitoring services are active THEN the Anti-Theft App SHALL consume less than 5% of battery per day
3. WHEN the device is in low battery mode THEN the Anti-Theft App SHALL reduce tracking frequency to conserve power
4. WHEN background services run THEN the Anti-Theft App SHALL use WorkManager for reliable task scheduling
5. WHEN the app is not in use THEN the Anti-Theft App SHALL minimize memory footprint to under 50MB


### Requirement 11

**User Story:** كمستخدم، أريد منع إيقاف تشغيل الجهاز بدون إذن، حتى لا يستطيع اللص إطفاء الجهاز وتعطيل التتبع

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL intercept power button long press events
2. WHEN power button is long-pressed without Master Password THEN the Anti-Theft App SHALL block the power menu and display password prompt
3. WHEN correct Master Password is entered THEN the Anti-Theft App SHALL allow access to power menu for 10 seconds
4. WHEN the device is being shut down without authorization THEN the Anti-Theft App SHALL attempt to cancel shutdown and trigger alarm
5. WHEN power menu is blocked THEN the Anti-Theft App SHALL log the attempt with timestamp and location

### Requirement 12

**User Story:** كمستخدم، أريد منع الوصول للإعدادات نهائياً أثناء وضع الحماية، حتى لا يستطيع اللص تغيير أي إعدادات

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL completely block all access to Settings app
2. WHEN Settings app launch is detected THEN the Anti-Theft App SHALL immediately force-close Settings and return user to home screen
3. WHEN Quick Settings panel is accessed THEN the Anti-Theft App SHALL block all setting toggles and shortcuts
4. WHEN user needs Settings access THEN the Anti-Theft App SHALL require disabling Protected Mode first using Master Password
5. WHEN any Settings access attempt occurs THEN the Anti-Theft App SHALL log the event, capture front camera photo, and trigger silent alert

### Requirement 13

**User Story:** كمستخدم، أريد حماية SIM card من التغيير، حتى أعرف إذا حاول اللص تغيير الشريحة

#### Acceptance Criteria

1. WHEN Protected Mode is enabled THEN the Anti-Theft App SHALL store current SIM card identifier
2. WHEN SIM card is removed or changed THEN the Anti-Theft App SHALL detect the change within 5 seconds
3. WHEN SIM change is detected THEN the Anti-Theft App SHALL send SMS to predefined emergency number with new SIM details
4. WHEN SIM change occurs THEN the Anti-Theft App SHALL trigger maximum volume alarm and enable Kiosk Mode
5. WHEN new SIM is inserted THEN the Anti-Theft App SHALL capture front camera photo and store with SIM change event

### Requirement 14

**User Story:** كمستخدم، أريد تفعيل وضع الحماية تلقائياً في أوقات محددة، حتى يكون الجهاز محمي دائماً عندما أكون خارج المنزل

#### Acceptance Criteria

1. WHEN the user configures auto-protection schedule THEN the Anti-Theft App SHALL store the time ranges and days
2. WHEN scheduled time arrives THEN the Anti-Theft App SHALL automatically enable Protected Mode
3. WHEN the user is in a trusted location (home WiFi) THEN the Anti-Theft App SHALL optionally disable auto-protection
4. WHEN auto-protection is triggered THEN the Anti-Theft App SHALL send notification to user
5. WHEN the user wants to override auto-protection THEN the Anti-Theft App SHALL require Master Password

### Requirement 15

**User Story:** كمستخدم، أريد نسخ احتياطي مشفر لإعدادات التطبيق، حتى أستطيع استعادتها على جهاز جديد

#### Acceptance Criteria

1. WHEN the user requests backup THEN the Anti-Theft App SHALL export all settings and logs as encrypted file
2. WHEN backup file is created THEN the Anti-Theft App SHALL encrypt it using Master Password
3. WHEN the user restores from backup THEN the Anti-Theft App SHALL require Master Password to decrypt
4. WHEN backup is restored THEN the Anti-Theft App SHALL import all settings and security logs
5. WHEN backup file is accessed without correct password THEN the Anti-Theft App SHALL refuse to decrypt after 3 failed attempts


### Requirement 16

**User Story:** كمستخدم، أريد إعداد رقم طوارئ موثوق، حتى أستطيع التحكم في الجهاز عن بعد بأمان

#### Acceptance Criteria

1. WHEN the user first enables Protected Mode THEN the Anti-Theft App SHALL require the user to enter an Emergency Contact phone number
2. WHEN Emergency Contact is entered THEN the Anti-Theft App SHALL validate the phone number format and store it encrypted
3. WHEN the user wants to change Emergency Contact THEN the Anti-Theft App SHALL require Master Password and send verification SMS to new number
4. WHEN verification SMS is sent THEN the Anti-Theft App SHALL require user to enter verification code within 5 minutes
5. WHEN Emergency Contact is successfully configured THEN the Anti-Theft App SHALL send test SMS to confirm communication channel is working

### Requirement 17

**User Story:** كمستخدم، أريد مراقبة محاولات إلغاء قفل الشاشة الفاشلة، حتى أعرف إذا كان هناك محاولات اختراق

#### Acceptance Criteria

1. WHEN the device screen lock is attempted with wrong PIN/pattern/password THEN the Anti-Theft App SHALL detect the failed attempt
2. WHEN 5 consecutive failed screen unlock attempts occur THEN the Anti-Theft App SHALL capture front camera photo and record location
3. WHEN failed unlock attempts are detected THEN the Anti-Theft App SHALL store them in Security Log with timestamp
4. WHEN 10 failed unlock attempts occur within 10 minutes THEN the Anti-Theft App SHALL send SMS alert to Emergency Contact with photo and location
5. WHEN device is successfully unlocked after failed attempts THEN the Anti-Theft App SHALL maintain the log but reset the consecutive counter

### Requirement 18

**User Story:** كمستخدم، أريد حماية التطبيق من الظهور في قائمة التطبيقات الحديثة، حتى لا يستطيع اللص معرفة وجوده

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL exclude itself from recent apps list (Overview screen)
2. WHEN the app is running in background THEN the Anti-Theft App SHALL hide its notification or show it as system service
3. WHEN the user searches for apps in launcher THEN the Anti-Theft App SHALL optionally hide its icon based on stealth mode setting
4. WHEN stealth mode is enabled THEN the Anti-Theft App SHALL only be accessible via dialer code (e.g., *#123456#)
5. WHEN dialer code is entered correctly THEN the Anti-Theft App SHALL open and request Master Password

### Requirement 19

**User Story:** كمستخدم، أريد تسجيل جميع المكالمات الواردة والصادرة أثناء وضع الحماية، حتى أعرف من استخدم الجهاز

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor all incoming and outgoing calls
2. WHEN a call is made or received THEN the Anti-Theft App SHALL log the phone number, duration, timestamp, and call type
3. WHEN a call log entry is created THEN the Anti-Theft App SHALL store it in encrypted Security Log
4. WHEN the user views call logs THEN the Anti-Theft App SHALL display all calls that occurred during Protected Mode
5. WHEN Emergency Contact number appears in call log THEN the Anti-Theft App SHALL mark it as trusted and highlight it differently

### Requirement 20

**User Story:** كمستخدم، أريد منع الوصول إلى وضع الاسترداد (Recovery Mode) والتمهيد الآمن (Safe Mode)، حتى لا يستطيع اللص تجاوز الحماية

#### Acceptance Criteria

1. WHEN the device attempts to boot into Safe Mode THEN the Anti-Theft App SHALL detect it and trigger alarm immediately upon boot
2. WHEN Safe Mode boot is detected THEN the Anti-Theft App SHALL send SMS to Emergency Contact with alert
3. WHEN the device is in Safe Mode THEN the Anti-Theft App SHALL display persistent notification that device is compromised
4. WHEN the user tries to boot into Recovery Mode THEN the Anti-Theft App SHALL have logged the last known location before shutdown
5. WHEN device reboots from Recovery Mode THEN the Anti-Theft App SHALL detect potential factory reset attempt and send alert if SIM is still present

### Requirement 21

**User Story:** كمستخدم، أريد تفعيل وضع الذعر السريع، حتى أستطيع حماية الجهاز فوراً في حالة الخطر

#### Acceptance Criteria

1. WHEN the user presses volume down button 5 times quickly THEN the Anti-Theft App SHALL activate panic mode immediately
2. WHEN panic mode is activated THEN the Anti-Theft App SHALL enable Kiosk Mode, trigger alarm, capture photo, and send SMS to Emergency Contact
3. WHEN panic mode is active THEN the Anti-Theft App SHALL display fake "Device Locked by Administrator" screen
4. WHEN panic mode is triggered THEN the Anti-Theft App SHALL start continuous location tracking every 30 seconds
5. WHEN the user wants to exit panic mode THEN the Anti-Theft App SHALL require Master Password entered twice for confirmation

### Requirement 22

**User Story:** كمستخدم، أريد حماية بيانات التطبيق من النسخ الاحتياطي، حتى لا يستطيع اللص استخراج كلمة المرور

#### Acceptance Criteria

1. WHEN the app is installed THEN the Anti-Theft App SHALL disable Android backup for app data in manifest
2. WHEN device backup is performed THEN the Anti-Theft App SHALL exclude all sensitive data including Master Password hash and Security Logs
3. WHEN the app detects backup attempt via ADB THEN the Anti-Theft App SHALL log it as suspicious activity
4. WHEN USB debugging is enabled on device THEN the Anti-Theft App SHALL send alert to Emergency Contact if Protected Mode is active
5. WHEN developer options are accessed THEN the Anti-Theft App SHALL log the event and optionally trigger alarm based on settings

### Requirement 23

**User Story:** كمستخدم، أريد مراقبة تطبيقات إدارة الملفات، حتى لا يستطيع اللص الوصول للبيانات المخزنة

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor launches of file manager apps
2. WHEN a file manager app is opened THEN the Anti-Theft App SHALL overlay password prompt before allowing access
3. WHEN correct Master Password is entered THEN the Anti-Theft App SHALL allow file manager access for 1 minute
4. WHEN file manager access time expires THEN the Anti-Theft App SHALL automatically close the file manager app
5. WHEN unauthorized file manager access is attempted THEN the Anti-Theft App SHALL log the event and capture front camera photo


### Requirement 24

**User Story:** كمستخدم، أريد اختبار جميع ميزات الحماية، حتى أتأكد أن التطبيق يعمل بشكل صحيح قبل الاعتماد عليه

#### Acceptance Criteria

1. WHEN the user opens test mode THEN the Anti-Theft App SHALL provide test buttons for all protection features
2. WHEN the user tests alarm feature THEN the Anti-Theft App SHALL play alarm for 5 seconds only and not send real SMS
3. WHEN the user tests camera capture THEN the Anti-Theft App SHALL take photo and display it without logging as security event
4. WHEN the user tests SMS commands THEN the Anti-Theft App SHALL simulate receiving commands without requiring actual SMS
5. WHEN the user completes all tests THEN the Anti-Theft App SHALL display test results report showing which features are working correctly
6. WHEN any test fails THEN the Anti-Theft App SHALL display detailed error message and suggest required permissions or settings

### Requirement 25

**User Story:** كمستخدم، أريد استقبال تقرير يومي عن حالة الحماية، حتى أطمئن أن الجهاز محمي

#### Acceptance Criteria

1. WHEN daily report time arrives (user configurable) THEN the Anti-Theft App SHALL generate status report
2. WHEN status report is generated THEN the Anti-Theft App SHALL include: Protected Mode status, battery level, last known location, and count of security events
3. WHEN status report is ready THEN the Anti-Theft App SHALL send it via SMS to Emergency Contact
4. WHEN no security events occurred THEN the Anti-Theft App SHALL send simple "All OK" message to save SMS costs
5. WHEN device battery is below 15% THEN the Anti-Theft App SHALL include battery warning in status report


### Requirement 26

**User Story:** كمستخدم، أريد إرسال موقع الجهاز تلقائياً عبر WhatsApp، حتى أتمكن من تتبع الجهاز بسهولة

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL send location via WhatsApp to predefined number (+201027888372) every 15 minutes
2. WHEN WhatsApp message is sent THEN the Anti-Theft App SHALL include GPS coordinates, Google Maps link, battery level, and timestamp
3. WHEN device location changes significantly (more than 100 meters) THEN the Anti-Theft App SHALL send immediate WhatsApp update
4. WHEN WhatsApp is not installed or not working THEN the Anti-Theft App SHALL fallback to SMS for location updates
5. WHEN panic mode is activated THEN the Anti-Theft App SHALL increase WhatsApp location updates to every 2 minutes

### Requirement 27

**User Story:** كمستخدم، أريد منع الوصول للإعدادات نهائياً، حتى لا يستطيع أي شخص تغيير إعدادات الجهاز

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL completely block access to Settings app without any password option
2. WHEN any attempt to open Settings is detected THEN the Anti-Theft App SHALL immediately close Settings and return to home screen
3. WHEN Quick Settings panel is pulled down THEN the Anti-Theft App SHALL block all toggles and settings shortcuts
4. WHEN Settings is accessed via any method (app, shortcut, notification, or system dialog) THEN the Anti-Theft App SHALL intercept and block it
5. WHEN user needs to access Settings THEN the Anti-Theft App SHALL require disabling Protected Mode first with Master Password

### Requirement 28

**User Story:** كمستخدم، أريد منع توصيل الجهاز بأي كمبيوتر غير موثوق، حتى لا يستطيع اللص نقل البيانات أو تثبيت برامج

#### Acceptance Criteria

1. WHEN USB cable is connected to device THEN the Anti-Theft App SHALL detect the connection immediately
2. WHEN USB connection is detected THEN the Anti-Theft App SHALL check if the connected computer is in trusted devices list
3. WHEN computer is not in trusted list THEN the Anti-Theft App SHALL block USB data transfer and show only charging mode
4. WHEN user wants to add trusted computer THEN the Anti-Theft App SHALL require Master Password and store computer identifier
5. WHEN USB debugging attempt is detected from untrusted computer THEN the Anti-Theft App SHALL trigger alarm and send alert to Emergency Contact
6. WHEN MTP or PTP mode is requested THEN the Anti-Theft App SHALL deny the request if computer is not trusted

### Requirement 29

**User Story:** كمستخدم، أريد حفظ قائمة الأجهزة الموثوقة بشكل دائم، حتى تبقى محفوظة حتى لو تم إغلاق الجهاز

#### Acceptance Criteria

1. WHEN a trusted computer is added THEN the Anti-Theft App SHALL store its identifier in encrypted persistent storage
2. WHEN device is powered off and on THEN the Anti-Theft App SHALL restore trusted devices list from encrypted storage
3. WHEN trusted device connects THEN the Anti-Theft App SHALL allow full USB access including data transfer
4. WHEN user wants to remove trusted device THEN the Anti-Theft App SHALL require Master Password confirmation
5. WHEN factory reset is attempted THEN the Anti-Theft App SHALL attempt to backup trusted devices list to cloud before reset


### Requirement 30

**User Story:** كمستخدم، أريد منع تغيير كلمة مرور قفل الشاشة، حتى لا يستطيع اللص قفل الجهاز بكلمة مرور جديدة

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor attempts to change screen lock password/PIN/pattern
2. WHEN screen lock change is attempted THEN the Anti-Theft App SHALL block the change and display warning
3. WHEN user needs to change screen lock THEN the Anti-Theft App SHALL require disabling Protected Mode first
4. WHEN screen lock change is blocked THEN the Anti-Theft App SHALL log the event and capture front camera photo
5. WHEN multiple screen lock change attempts occur THEN the Anti-Theft App SHALL trigger alarm and send SMS to Emergency Contact

### Requirement 31

**User Story:** كمستخدم، أريد منع إضافة حسابات جديدة على الجهاز، حتى لا يستطيع اللص ربط الجهاز بحسابه

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor attempts to add new Google or other accounts
2. WHEN account addition is attempted THEN the Anti-Theft App SHALL block the addition and close the account setup
3. WHEN user needs to add account THEN the Anti-Theft App SHALL require disabling Protected Mode first
4. WHEN account addition is blocked THEN the Anti-Theft App SHALL log the event with timestamp
5. WHEN existing account removal is attempted THEN the Anti-Theft App SHALL block it and trigger security alert

### Requirement 32

**User Story:** كمستخدم، أريد منع تثبيت أو إزالة التطبيقات، حتى لا يستطيع اللص تثبيت أدوات اختراق أو إزالة تطبيقاتي

#### Acceptance Criteria

1. WHEN Protected Mode is active THEN the Anti-Theft App SHALL monitor app installation attempts from any source
2. WHEN app installation is attempted THEN the Anti-Theft App SHALL block the installation and close installer
3. WHEN app uninstallation is attempted THEN the Anti-Theft App SHALL block the uninstallation
4. WHEN user needs to install/uninstall apps THEN the Anti-Theft App SHALL require disabling Protected Mode first
5. WHEN installation/uninstallation is blocked THEN the Anti-Theft App SHALL log the event and capture front camera photo

### Requirement 33

**User Story:** كمستخدم، أريد حماية الجهاز من إعادة ضبط المصنع، حتى لا يستطيع اللص مسح بياناتي وإعادة استخدام الجهاز

#### Acceptance Criteria

1. WHEN factory reset is attempted from Settings THEN the Anti-Theft App SHALL block the reset completely
2. WHEN factory reset is attempted from Recovery Mode THEN the Anti-Theft App SHALL have sent last location before shutdown
3. WHEN device boots after factory reset THEN the Anti-Theft App SHALL require Google account verification (FRP)
4. WHEN factory reset protection is active THEN the Anti-Theft App SHALL ensure FRP is enabled on device
5. WHEN factory reset is blocked THEN the Anti-Theft App SHALL trigger maximum alarm and send SMS to Emergency Contact

### Requirement 34

**User Story:** كمستخدم، أريد تسجيل صوتي للمحيط عند اكتشاف نشاط مشبوه، حتى أحصل على أدلة إضافية

#### Acceptance Criteria

1. WHEN suspicious activity is detected THEN the Anti-Theft App SHALL optionally start audio recording for 30 seconds
2. WHEN audio recording is captured THEN the Anti-Theft App SHALL store it encrypted with event details
3. WHEN panic mode is activated THEN the Anti-Theft App SHALL start continuous audio recording
4. WHEN user views security logs THEN the Anti-Theft App SHALL allow playback of recorded audio
5. WHEN audio recording feature is enabled THEN the Anti-Theft App SHALL request microphone permission

### Requirement 35

**User Story:** كمستخدم، أريد إرسال صورة اللص مباشرة عبر الإنترنت، حتى أحصل عليها فوراً بدون انتظار

#### Acceptance Criteria

1. WHEN intruder photo is captured THEN the Anti-Theft App SHALL upload it to cloud storage immediately
2. WHEN photo is uploaded THEN the Anti-Theft App SHALL send link via WhatsApp and SMS to Emergency Contact
3. WHEN internet is not available THEN the Anti-Theft App SHALL queue photo for upload when connection is restored
4. WHEN multiple photos are captured THEN the Anti-Theft App SHALL upload all of them in sequence
5. WHEN cloud upload fails THEN the Anti-Theft App SHALL retry up to 5 times with exponential backoff
