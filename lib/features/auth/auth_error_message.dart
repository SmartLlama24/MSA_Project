import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException || error is TimeoutException) {
    return 'Could not connect. Check your internet connection and try again.';
  }

  if (error is AuthException) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();

    if (code == 'weak_password' ||
        error is AuthWeakPasswordException ||
        message.contains('weak password') ||
        message.contains('password should be')) {
      return 'Choose a stronger password and try again.';
    }
    if (code == 'user_already_exists' ||
        message.contains('already registered') ||
        message.contains('user already exists')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Confirm your email from the message we sent, then sign in.';
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'Email or password is incorrect.';
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return 'Enter a valid email address.';
    }
    if (code == 'too_many_requests' ||
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        error.statusCode == '429') {
      return 'Too many attempts. Please wait a little and try again.';
    }
  }

  return 'We could not complete that request. Check your details and try again.';
}
