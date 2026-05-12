import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _serviceId  = 'service_o62w6ki';
  static const String _publicKey  = 'kpRUwsHTxmAAXWvIL';

  // ── TEMPLATE IDs ───────────────────────────────────────────────────────────
  static const String _templateBeneficiaryNotify    = 'template_y8k1cio';
  static const String _templateInactivityConfirm    = 'template_w7h0309';
  static const String _templateAccessApproved       = 'template_9ygz5ga';
  static const String _templateAccessRejected       = 'template_e9f5u87';
  static const String _templateRegistrationApproved = 'template_l3c6gwp';
  static const String _templateRegistrationRejected = 'template_ja2cu0r';
  static const String _templatePinSetupOtp          = 'REPLACE_WITH_YOUR_TEMPLATE_ID';

  // ── CORE SEND ──────────────────────────────────────────────────────────────
  static Future<bool> _sendEmail({
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      final body = {
        'service_id':      _serviceId,
        'template_id':     templateId,
        'user_id':         _publicKey,
        'template_params': templateParams,
      };

      debugPrint('📧 Sending email...');
      debugPrint('   Template: $templateId');
      debugPrint('   To: ${templateParams['to_email']}');
      debugPrint('   Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin':       'http://localhost',
        },
        body: jsonEncode(body),
      );

      debugPrint('📧 Response status: ${response.statusCode}');
      debugPrint('📧 Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Email sent successfully [$templateId]');
        return true;
      } else {
        debugPrint('❌ Email failed [$templateId]: '
            'Status=${response.statusCode} Body=${response.body}');
        return false;
      }
    } catch (e, stack) {
      debugPrint('❌ Email error [$templateId]: $e');
      debugPrint('   Stack: $stack');
      return false;
    }
  }

  // ── 1. BENEFICIARY ASSIGNED ────────────────────────────────────────────────
  static Future<void> sendBeneficiaryNotification({
    required String beneficiaryEmail,
    required String beneficiaryName,
    required String ownerName,
  }) async {
    await _sendEmail(
      templateId: _templateBeneficiaryNotify,
      templateParams: {
        'to_email':         beneficiaryEmail,
        'to_name':          beneficiaryName,
        'beneficiary_name': beneficiaryName,
        'owner_name':       ownerName,
        'accept_url':
        'mailto:nurulnadiabatrisyia@gmail.com?subject=Accept Beneficiary Role',
        'decline_url':
        'mailto:nurulnadiabatrisyia@gmail.com?subject=Decline Beneficiary Role',
      },
    );
  }

  // ── 2. INACTIVITY CONFIRMATION TO BENEFICIARY ─────────────────────────────
  static Future<void> sendInactivityConfirmation({
    required String beneficiaryEmail,
    required String beneficiaryName,
    required String ownerName,
  }) async {
    await _sendEmail(
      templateId: _templateInactivityConfirm,
      templateParams: {
        'to_email':         beneficiaryEmail,
        'to_name':          beneficiaryName,
        'beneficiary_name': beneficiaryName,
        'owner_name':       ownerName,
      },
    );
  }

  // ── 3. EMERGENCY ACCESS APPROVED ──────────────────────────────────────────
  static Future<void> sendAccessApproved({
    required String beneficiaryEmail,
    required String beneficiaryName,
    required String ownerName,
  }) async {
    await _sendEmail(
      templateId: _templateAccessApproved,
      templateParams: {
        'to_email':         beneficiaryEmail,
        'to_name':          beneficiaryName,
        'beneficiary_name': beneficiaryName,
        'owner_name':       ownerName,
      },
    );
  }

  // ── 4. EMERGENCY ACCESS REJECTED ──────────────────────────────────────────
  static Future<void> sendAccessRejected({
    required String beneficiaryEmail,
    required String beneficiaryName,
    required String ownerName,
    required String rejectReason,
  }) async {
    await _sendEmail(
      templateId: _templateAccessRejected,
      templateParams: {
        'to_email':         beneficiaryEmail,
        'to_name':          beneficiaryName,
        'beneficiary_name': beneficiaryName,
        'owner_name':       ownerName,
        'reject_reason':    rejectReason,
      },
    );
  }

  // ── 5. PIN SETUP OTP ──────────────────────────────────────────────────────
  static Future<bool> sendPinSetupOtp({
    required String userEmail,
    required String userName,
    required String otpCode,
  }) async {
    return await _sendEmail(
      templateId: _templatePinSetupOtp,
      templateParams: {
        'to_email': userEmail,
        'to_name':  userName,
        'otp_code': otpCode,
      },
    );
  }

  // ── 7. eKYC REGISTRATION APPROVED ─────────────────────────────────────────
  static Future<void> sendRegistrationApproved({
    required String userEmail,
    required String userName,
  }) async {
    await _sendEmail(
      templateId: _templateRegistrationApproved,
      templateParams: {
        'to_email':   userEmail,
        'to_name':    userName,
        'user_name':  userName,
        'user_email': userEmail,
      },
    );
  }

  // ── 8. eKYC REGISTRATION REJECTED ─────────────────────────────────────────
  static Future<void> sendRegistrationRejected({
    required String userEmail,
    required String userName,
    required String rejectionReason,
  }) async {
    await _sendEmail(
      templateId: _templateRegistrationRejected,
      templateParams: {
        'to_email':         userEmail,
        'to_name':          userName,
        'user_name':        userName,
        'user_email':       userEmail,
        'rejection_reason': rejectionReason,
      },
    );
  }
}
