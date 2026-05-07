import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_payment_model.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_shared_models.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/v2/paypal_service_v2.dart';

/// UI-independent PayPal checkout controller.
///
/// Decouples the PayPal payment logic from any specific WebView or UI widget,
/// allowing developers to use **any** WebView implementation (InAppWebView,
/// webview_flutter, custom browser, etc.) to complete the PayPal checkout flow.
///
/// ## Lifecycle
///
/// 1. Create a controller with your [PaypalCheckoutConfig].
/// 2. Call [initialize] to create the order and get the approval URL.
/// 3. Load [approvalUrl] in your own WebView.
/// 4. In your WebView's URL interception, call [matchUrl] to detect
///    return/cancel redirects.
/// 5. When a return URL is detected, call [handleReturnUrl] to
///    capture the payment.
/// 6. When a cancel URL is detected, call [handleCancel].
/// 7. Call [dispose] when done.
///
/// ## Example
///
/// ```dart
/// final controller = PaypalCheckoutController(config: myConfig);
///
/// // Step 1: Initialize and get approval URL
/// final result = await controller.initialize();
/// result.fold(
///   (error) => print('Error: ${error.message}'),
///   (paymentModel) {
///     // Step 2: Load paymentModel.approvalUrl in your WebView
///     myWebViewController.loadUrl(paymentModel.approvalUrl);
///   },
/// );
///
/// // Step 3: In your WebView's URL interception
/// final match = controller.matchUrl(currentUrl);
/// if (match == PayPalUrlMatch.returnUrl) {
///   await controller.handleReturnUrl(Uri.parse(currentUrl));
/// } else if (match == PayPalUrlMatch.cancelUrl) {
///   controller.handleCancel();
/// }
/// ```
class PaypalCheckoutController {
  /// The checkout configuration (callbacks, credentials, order, etc.).
  final PaypalCheckoutConfig config;

  /// The PayPal payment model created after initialization.
  ///
  /// Contains the approval URL, order ID, return/cancel URLs, etc.
  /// Available after a successful [initialize] call.
  PaypalPaymentModel? get paymentModel => _paymentModel;
  PaypalPaymentModel? _paymentModel;

  /// Whether the controller has been initialized successfully.
  bool get isInitialized => _paymentModel != null;

  /// The approval URL to load in your WebView.
  ///
  /// Only available after a successful [initialize] call.
  String? get approvalUrl => _paymentModel?.approvalUrl;

  /// The return URL pattern to watch for in your WebView.
  ///
  /// Only available after a successful [initialize] call.
  String? get returnUrl => _paymentModel?.returnURL;

  /// The cancel URL pattern to watch for in your WebView.
  ///
  /// Only available after a successful [initialize] call.
  String? get cancelUrl => _paymentModel?.cancelURL;

  /// Internal service instance.
  PaypalServicesV2? _services;

  /// Whether the payment flow has already been handled (prevent double-fire).
  bool _handled = false;

  PaypalCheckoutController({required this.config});

  /// Initializes the PayPal payment flow.
  ///
  /// This method:
  /// 1. Creates the V2 service.
  /// 2. Creates the order (or uses backend-provided approval URL).
  /// 3. Returns the [PaypalPaymentModel] containing the approval URL.
  ///
  /// After this returns successfully, load [approvalUrl] in your WebView.
  ///
  /// Returns:
  /// - `Right(PaypalPaymentModel)` on success.
  /// - `Left(PayPalErrorModel)` on any error.
  Future<Either<PayPalErrorModel, PaypalPaymentModel>> initialize() async {
    _services = PaypalServicesV2(
      getAccessTokenFunction: config.getAccessToken,
      sandboxMode: config.sandboxMode,
      clientId: config.clientId,
      secretKey: config.secretKey,
      overrideInsecureClientCredentials:
          config.overrideInsecureClientCredentials,
    );

    try {
      final result = await _services!.initialize(
        getApprovalUrl: config.approvalUrl,
        payPalOrder: config.payPalOrder,
      );

      return result.fold(
        (error) => Left(error),
        (model) {
          _paymentModel = model;
          _handled = false;
          return Right(model);
        },
      );
    } catch (e) {
      return Left(
        PayPalErrorModel(
          error: e.toString(),
          message: "Unknown error during initialization",
          key: "UNKNOWN_ERROR",
          code: 500,
        ),
      );
    }
  }

  /// Checks whether the given [url] matches the return or cancel URL.
  ///
  /// Use this in your WebView's URL interception to determine
  /// which action to take.
  ///
  /// Returns:
  /// - [PayPalUrlMatch.returnUrl] if the user approved the payment.
  /// - [PayPalUrlMatch.cancelUrl] if the user cancelled.
  /// - [PayPalUrlMatch.none] if the URL is not a PayPal redirect.
  PayPalUrlMatch matchUrl(String url) {
    if (_paymentModel == null) return PayPalUrlMatch.none;

    if (url.contains(_paymentModel!.returnURL)) {
      return PayPalUrlMatch.returnUrl;
    }

    if (url.contains(_paymentModel!.cancelURL)) {
      return PayPalUrlMatch.cancelUrl;
    }

    return PayPalUrlMatch.none;
  }

  /// Handles the PayPal return URL after user approval.
  ///
  /// Call this when your WebView detects a URL matching [returnUrl].
  ///
  /// Captures the order and delivers the result via
  /// [PaypalCheckoutConfig.onUserPayment] or [PaypalCheckoutConfig.onError].
  ///
  /// [url] is the full return URL. Can be `null` for backend flows.
  Future<void> handleReturnUrl([Uri? url]) async {
    if (_handled) return;
    _handled = true;
    await _captureOrderV2();
  }

  /// Handles the PayPal cancel URL.
  ///
  /// Call this when your WebView detects a URL matching [cancelUrl].
  ///
  /// Invokes [PaypalCheckoutConfig.onCancel].
  void handleCancel() {
    if (_handled) return;
    _handled = true;
    config.onCancel();
  }

  /// Resets the controller to allow re-initialization.
  ///
  /// Call this if you want to restart the payment flow.
  void reset() {
    _paymentModel = null;
    _services = null;
    _handled = false;
  }

  /// Releases resources held by this controller.
  void dispose() {
    reset();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE: V2 capture flow
  // ---------------------------------------------------------------------------

  Future<void> _captureOrderV2() async {
    final model = _paymentModel;
    if (model == null) return;

    // Backend-driven flow: no token/orderId → delegate to callback
    if (model.accessToken == null || model.orderId == null) {
      final result = await config.onUserPayment(null, model);
      result.fold(
        (PayPalErrorModel error) {
          if (kDebugMode) {
            print("Backend flow => error: $error");
          }
          config.onError(error);
        },
        (success) {
          if (kDebugMode) {
            print("Backend flow => Payment Captured: $success");
          }
        },
      );
      return;
    }

    final result = await _services!.captureOrder(
      model.orderId!,
      model.accessToken!,
    );

    result.fold(
      (error) => config.onError(error),
      (success) => config.onUserPayment(success, model),
    );
  }
}

/// Result of matching a URL against the PayPal return/cancel URLs.
enum PayPalUrlMatch {
  /// The URL matches the return URL (payment approved).
  returnUrl,

  /// The URL matches the cancel URL (payment cancelled).
  cancelUrl,

  /// The URL does not match either URL.
  none,
}
