/// Cloud upload service for the Anti-Theft Protection app.
///
/// This module provides cloud photo upload functionality with:
/// - Immediate upload when internet is available
/// - Offline queue for uploads when internet is unavailable
/// - Exponential backoff retry logic (up to 5 retries)
/// - Link sharing via WhatsApp and SMS
///
/// Requirements: 35.1, 35.2, 35.3, 35.5
library cloud_upload;

export 'i_cloud_upload_service.dart';
export 'cloud_upload_service.dart';
