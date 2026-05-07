import 'package:dartz/dartz.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_payment_model.dart';

/// Base model for all PayPal-related responses and results.
///
/// Provides a consistent structure for:
/// - [message]: Human-readable description of the result.
/// - [key]: A stable key useful for localization or error handling.
/// - [code]: Numeric status code (e.g. HTTP-like or custom).
class PayPalBaseModel {
  /// Human-readable message describing the result or error.
  final String message;

  /// Machine-readable key used for error handling / translations.
  final String key;

  /// Numeric status or error code (e.g. 200, 400, 500).
  final int code;

  PayPalBaseModel({
    required this.message,
    required this.key,
    required this.code,
  });
}

/// Model representing a PayPal access token result.
///
/// Typically returned by the `getAccessToken()` flow and used to authorize
/// subsequent PayPal API calls.
class PayPalAccessTokenModel extends PayPalBaseModel {
  /// The OAuth access token to be used in PayPal API calls.
  final String accessToken;

  PayPalAccessTokenModel({
    required this.accessToken,
    required super.message,
    required super.key,
    required super.code,
  });
}

/// Model representing a PayPal error in a structured way.
///
/// Wraps the original [error] payload (string, map, etc.), along with
/// standardized [message], [key], and [code] from [PayPalBaseModel].
class PayPalErrorModel extends PayPalBaseModel {
  /// The raw error payload (can be string, JSON map, etc.).
  final dynamic error;

  PayPalErrorModel({
    required this.error,
    required super.message,
    required super.key,
    required super.code,
  });

  @override
  String toString() {
    return 'PayPalErrorModel{error: $error, message: $message, key: $key, code: $code}';
  }
}

/// Callback type invoked when a PayPal operation fails.
///
/// Provides a [PayPalErrorModel] describing the failure.
typedef PayPalOnError = dynamic Function(PayPalErrorModel error);

/// Function that asynchronously returns a PayPal access token.
///
/// Used when the app relies on a backend to generate OAuth tokens.
typedef PayPalGetAccessToken = Future<String> Function();

/// Function that returns a `transactions`/`purchase_units` map.
///
/// Used by order builders to supply the core PayPal payload.
typedef PayPalTransactionsFunction = Map<String, dynamic> Function();

/// Base class for PayPal order request models.
///
/// Implementations must:
/// - Provide a valid JSON payload via [toJson].
/// - Report if they are empty via [isEmpty]/[isNotEmpty].
abstract class PayPalOrderRequestBase {
  const PayPalOrderRequestBase();

  /// Should return the exact JSON structure expected by the PayPal API.
  Map<String, dynamic> toJson();

  /// Whether this order request has no meaningful content.
  ///
  /// Used to guard against sending empty purchase units.
  bool get isEmpty;

  /// Convenience getter for `!isEmpty`.
  bool get isNotEmpty => !isEmpty;
}

/// Default deep link return URL used when the PayPal payment succeeds.
///
/// This is the URL PayPal redirects to after a successful approval.
const defaultReturnURL = 'paypal-sdk://success';

/// Default deep link cancel URL used when the PayPal payment is cancelled.
///
/// This is the URL PayPal redirects to when the user cancels the checkout.
const defaultCancelURL = 'paypal-sdk://cancel';

/// Callback type invoked when a PayPal payment completes successfully.
///
/// - [response]: Optional PayPal response body wrapped in [PayPalSuccessPaymentModel].
/// - [payment]: The original [PaypalPaymentModel] used for the flow.
typedef PayPalOnSuccess = Future<Either<PayPalErrorModel, dynamic>> Function(
  PayPalSuccessPaymentModel? response,
  PaypalPaymentModel payment,
);

/// Model representing a successful PayPal payment or capture.
///
/// Wraps the raw PayPal [data] along with standardized base fields from
/// [PayPalBaseModel].
class PayPalSuccessPaymentModel extends PayPalBaseModel {
  /// Raw PayPal response body (capture, order details, etc.).
  final dynamic data;

  PayPalSuccessPaymentModel({
    required this.data,
    required super.message,
    required super.key,
    required super.code,
  });
}
