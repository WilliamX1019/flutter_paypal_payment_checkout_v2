import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment_checkout_v2/flutter_paypal_payment_checkout_v2.dart';

/// A function signature that returns a `PaypalPaymentModel`.
///
/// This typedef is used by services that request an approval URL from PayPal
/// during the order creation or payment setup flow.
typedef PayPalGetCheckOutUrl
    = Future<Either<PayPalErrorModel, PaypalPaymentModel>> Function();

/// Represents all essential PayPal payment details required by the client
/// to proceed with the approval, capture, or final execution flow.
///
/// This model is typically returned after creating a PayPal order and contains:
/// - The approval URL for redirecting the user to PayPal.
/// - The `orderId` needed for capture.
/// - Optional `executeUrl` / `accessToken` (used in older PayPal V1 flows).
/// - Return and cancel URLs.
/// - Status information and common base error fields.
///
/// Inherits:
/// - `message`, `key`, `code` from `PayPalBaseModel` for standardized error handling.
class PaypalPaymentModel extends PayPalBaseModel {
  /// The unique PayPal order ID returned after creating the order.
  final String? orderId;

  /// The URL where the user should be redirected to approve the payment.
  final String approvalUrl;

  /// Return URL where PayPal will redirect after successful approval.
  final String returnURL;

  /// Cancel URL where PayPal redirects if the user cancels the payment.
  final String cancelURL;

  /// Optional PayPal order/payment status.
  final String? status;

  /// Optional OAuth access token (commonly used in PayPal V1 integrations).
  final String? accessToken;

  /// Optional execute URL used in legacy PayPal execution flow (V1 only).
  final String? executeUrl;

  PaypalPaymentModel({
    required this.approvalUrl,
    required this.executeUrl,
    required this.accessToken,
    this.returnURL = defaultReturnURL,
    this.cancelURL = defaultCancelURL,
    required super.message,
    required super.key,
    required super.code,
    required this.status,
    required this.orderId,
  });

  /// Converts this model to JSON for logging or local persistence.
  ///
  /// Useful when caching the payment state or debugging PayPal responses.
  Map<String, dynamic> toJson() {
    return {
      "orderId": orderId,
      "approvalUrl": approvalUrl,
      "executeUrl": executeUrl,
      "accessToken": accessToken,
      "returnURL": returnURL,
      "cancelURL": cancelURL,
      "status": status,
      "message": message,
      "key": key,
      "code": code,
    };
  }
}

/// Supported PayPal API versions.
///
/// - [PayPalApiVersion.v1] → Legacy Payments API V1.
/// - [PayPalApiVersion.v2] → Modern Orders API V2 (recommended).

enum PayPalApiVersion { v1, v2 }

class PaypalCheckoutConfig {
  /// Which PayPal API version to use.
  ///
  /// - [PayPalApiVersion.v1] → uses [PaypalServicesV1] and V1 models.
  /// - [PayPalApiVersion.v2] → uses [PaypalServicesV2] and V2 models.
  final PayPalApiVersion version;

  /// Called when the user completes the payment flow.
  ///
  /// - `response` may be `null` when using the **backend-driven** flow
  ///   (where the server executes/captures and the client only receives
  ///   the `PaypalPaymentModel`).
  /// - `payment` is always the [PaypalPaymentModel] created at the start.
  final PayPalOnSuccess onUserPayment;

  /// Called when the user cancels the PayPal checkout flow.
  final Function onCancel;

  /// Called when any error occurs during:
  /// - Initialization
  /// - Network calls
  /// - Version mismatch
  /// - Unknown exceptions
  final PayPalOnError onError;

  /// App bar title displayed at the top of the checkout screen.
  final String appBarTitle;

  /// Optional note or description (not currently used in logic, but available
  /// for future enhancements or custom UIs).
  final String? note;

  /// Most secure workflow:
  ///
  /// Your backend:
  /// - Creates the PayPal order/payment.
  /// - Returns a [PaypalPaymentModel] with `approvalUrl`.
  ///
  /// The client:
  /// - Only loads that URL and listens for return/cancel.
  ///
  /// Use this when you do **not** want to expose credentials or perform
  /// PayPal API calls in the client.
  final PayPalGetCheckOutUrl? approvalUrl;

  /// Less secure and generally not recommended for production.
  ///
  /// Used when:
  /// - The client must request an access token directly.
  /// - The backend cannot (or does not) create the order itself.
  ///
  /// This function should return a **server-generated** access token,
  /// not client credentials.
  final PayPalGetAccessToken? getAccessToken;

  /// Should NEVER be used in production.
  ///
  /// Only for testing or demo apps where you cannot set up a backend yet.
  /// Passing [clientId] and [secretKey] into the app is insecure because
  /// they can be extracted from the binary.
  final String? clientId, secretKey;

  /// Optional custom loading widget shown while:
  /// - Initializing the payment/order, or
  /// - Waiting for callbacks.
  final Widget? loadingIndicator;

  /// The PayPal order model used to build the request.
  ///
  /// - For V1: [PayPalOrderRequestV1]
  /// - For V2: [PayPalOrderRequestV2]
  ///
  /// When using [approvalUrl], this may be `null` if your backend
  /// handles all order creation and execution logic.
  final PayPalOrderRequestBase? payPalOrder;

  /// When `true` → uses PayPal sandbox endpoints.
  ///
  /// When `false` → uses live production endpoints.
  final bool sandboxMode;

  /// By default this is `false`.
  ///
  /// If set to `true`, it bypasses the safety check that normally prevents
  /// using [clientId]/[secretKey] in non-sandbox mode.
  ///
  /// ⚠️ Only set this to `true` if you **fully understand the security risk**.
  final bool overrideInsecureClientCredentials;

  const PaypalCheckoutConfig({
    required this.onUserPayment,
    required this.getAccessToken,
    required this.onError,
    required this.onCancel,
    required this.payPalOrder,
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
    this.overrideInsecureClientCredentials = false,
    this.appBarTitle = "Paypal Payment",
    this.note = '',
    this.loadingIndicator,
    this.approvalUrl,
    required this.version,
  });
}
