/// Flutter PayPal Payment Checkout (V1 & V2).
///
/// This library exposes a single high-level widget:
/// [PaypalCheckoutView]
///
/// It handles:
/// - Creating a PayPal payment/order (via V1 or V2 APIs)
/// - Rendering the approval page in an in-app webview
/// - Listening to return/cancel URLs
/// - Executing/capturing the payment (if needed)
/// - Returning the result via callbacks
library flutter_paypal_payment_checkout_v2;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_services_base.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_shared_models.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/v1/paypal_service_v1.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/v2/paypal_service_v2.dart';

import 'models/paypal_payment_model.dart'
    show PaypalPaymentModel, PaypalCheckoutConfig, PayPalApiVersion;


/// Main checkout widget that handles the entire PayPal flow.
///
/// This widget:
/// - Initializes the selected PayPal API service (V1 or V2).
/// - Either:
///   - Uses a backend-provided [approvalUrl], **or**
///   - Creates the payment/order directly from the client.
/// - Opens an in-app webview to show the PayPal approval page.
/// - Listens for success/cancel redirects using return/cancel URLs.
/// - Executes/captures the payment for client-side flows.
/// - Returns the result to [onUserPayment], [onCancel], or [onError].
class PaypalCheckoutView extends StatefulWidget {
 final PaypalCheckoutConfig config;

  const PaypalCheckoutView({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PaypalCheckoutViewState();
}

class _PaypalCheckoutViewState extends State<PaypalCheckoutView> {
  /// Holds the created PayPal payment/order info (approvalUrl, orderId, etc.).
  PaypalPaymentModel? paymentModel;

  /// Underlying service implementation:
  /// - [PaypalServicesV1] or [PaypalServicesV2].
  late PaypalServicesBase services;

  /// Web loading progress (0.0–1.0).
  double progress = 0;

  /// Controller for the embedded InAppWebView.
  late InAppWebViewController webView;

  /// Convenience getter to check if the widget is configured for V1.
  bool get _isV1 => widget.config.version == PayPalApiVersion.v1;

  /// Initializes the PayPal flow:
  ///
  /// 1. Chooses the correct service (V1 or V2).
  /// 2. Validates order/service version compatibility.
  /// 3. Calls [PaypalServicesBase.initialize] to:
  ///    - Either use [approvalUrl] (backend flow)
  ///    - Or create the order/payment directly (client flow).
  /// 4. Stores the resulting [PaypalPaymentModel] in state.
  Future<void> _initializePayment() async {
    // Pick the correct service implementation based on the order type
    if (_isV1) {
      services = PaypalServicesV1(
        getAccessTokenFunction: widget.config.getAccessToken,
        sandboxMode: widget.config.sandboxMode,
        clientId: widget.config.clientId,
        secretKey: widget.config.secretKey,
        overrideInsecureClientCredentials:
            widget.config.overrideInsecureClientCredentials,
      );
    } else {
      services = PaypalServicesV2(
        getAccessTokenFunction: widget.config.getAccessToken,
        sandboxMode: widget.config.sandboxMode,
        clientId: widget.config.clientId,
        secretKey: widget.config.secretKey,
        overrideInsecureClientCredentials:
            widget.config.overrideInsecureClientCredentials,
      );
    }

    // Optional safety: ensure order type matches selected service version.
    if (widget.config.payPalOrder != null) {
      final isOrderV1 = widget.config.payPalOrder!.isV1;
      final isServiceV1 = services is PaypalServicesV1;

      if (isOrderV1 != isServiceV1) {
        widget.config.onError(
          PayPalErrorModel(
            error: "Order type does not match selected PayPal service version.",
            message:
                "You passed a ${isOrderV1 ? 'V1' : 'V2'} order into a ${isServiceV1 ? 'V1' : 'V2'} service.\n\n"
                "Make sure:\n"
                "- PayPalOrderRequestV1 → PaypalServicesV1\n"
                "- PayPalOrderRequestV2 → PaypalServicesV2",
            key: "ORDER_VERSION_MISMATCH",
            code: 400,
          ),
        );
        return; // Stop here — do NOT continue
      }
    }

    try {
      final result = await services.initialize(
        getApprovalUrl: widget.config.approvalUrl,
        payPalOrder: widget.config.payPalOrder,
      );

      result.fold(
        (error) => widget.config.onError(error),
        (paymentModel) {
          setState(() {
            this.paymentModel = paymentModel;
          });
        },
      );
    } catch (e) {
      widget.config.onError(
        PayPalErrorModel(
          error: e.toString(),
          message: "Unknown error",
          key: "UNKNOWN_ERROR",
          code: 500,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  Widget build(BuildContext context) {
    // While payment/order is initializing → show a loading screen.
    if (paymentModel == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(widget.config.appBarTitle),
        ),
        body: Center(
          child: widget.config.loadingIndicator ?? const CircularProgressIndicator(),
        ),
      );
    }

    // Once we have a paymentModel with approvalUrl → render the webview.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.config.appBarTitle),
      ),
      body: Stack(
        children: <Widget>[
          InAppWebView(
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;
              final urlStr = url.toString();

              // Use the URLs coming back from PaypalPaymentModel for both V1 and V2
              final returnURL = paymentModel!.returnURL;
              final cancelURL = paymentModel!.cancelURL;

              if (urlStr.contains(returnURL)) {
                await _handleReturnUrl(url, context);
                return NavigationActionPolicy.CANCEL;
              }

              if (urlStr.contains(cancelURL)) {
                widget.config.onCancel();
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            initialUrlRequest: URLRequest(
              url: WebUri(paymentModel!.approvalUrl),
            ),
            onWebViewCreated: (controller) {
              webView = controller;
            },
            onCloseWindow: (controller) {
              widget.config.onCancel();
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                this.progress = progress / 100;
              });
            },
          ),
          progress < 1
              ? SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(value: progress),
                )
              : const SizedBox(),
        ],
      ),
    );
  }

  /// Handles the PayPal return URL after approval.
  ///
  /// Delegates to:
  /// - [_executePaymentV1] for V1 flows.
  /// - [_captureOrderV2] for V2 flows.
  Future<void> _handleReturnUrl(Uri? url, BuildContext context) async {
    // Don't try to be smart here — just delegate.
    if (_isV1) {
      await _executePaymentV1(url);
    } else {
      await _captureOrderV2();
    }
  }

  /// Completes the V1 payment using the `execute` URL and `PayerID`.
  ///
  /// Behavior:
  /// - If [paymentModel.accessToken] or [paymentModel.executeUrl] is `null`,
  ///   this indicates a backend-driven execution/capture flow → we simply call
  ///   [onUserPayment] with `response = null` and return.
  /// - Otherwise:
  ///   - Extracts `PayerID` from the return URL query.
  ///   - Calls [PaypalServicesV1.executePayment].
  ///   - Returns the result via [onUserPayment] or [onError].
  Future<void> _executePaymentV1(Uri? url) async {
    final model = paymentModel;
    if (model == null) return;

    // If you're in the new flow where the backend will execute/capture,
    // you can just exit early when there's no token/executeUrl.
    if (model.accessToken == null || model.executeUrl == null) {
      // backend will call execute/capture – nothing to do on client
      widget.config.onUserPayment(
        null,
        model,
      );
      return;
    }

    // Extract PayerID from return URL
    final payerId = url?.queryParameters['PayerID'];

    if (payerId == null) {
      widget.config.onError(
        PayPalErrorModel(
          error: "PayerID is null",
          message: "PayerID is null",
          key: "PAYMENT_EXECUTE_PAYER_ID_NULL",
          code: 500,
        ),
      );
      return;
    }

    final v1 = services as PaypalServicesV1;

    final result = await v1.executePayment(
      model.executeUrl!,
      payerId,
      model.accessToken!,
    );

    result.fold(
      (error) => widget.config.onError(error),
      (success) {
        widget.config.onUserPayment(
          success,
          model,
        );
      },
    );
  }

  /// Captures a V2 order after the user returns from PayPal.
  ///
  /// Behavior:
  /// - If [paymentModel.accessToken] or [paymentModel.orderId] is `null`,
  ///   this indicates a backend-driven capture flow → we simply call
  ///   [onUserPayment] with `response = null` and return.
  /// - Otherwise:
  ///   - Calls [PaypalServicesV2.captureOrder].
  ///   - Returns the result via [onUserPayment] or [onError].
  Future<void> _captureOrderV2() async {
    final model = paymentModel;
    if (model == null) return;

    // If you're in the new flow where the backend will execute/capture,
    // you can just exit early when there's no token/orderId.
    if (model.accessToken == null || model.orderId == null) {
      final result = await widget.config.onUserPayment(
        null,
        model,
      );
      return result.fold(
        (PayPalErrorModel error) {
          if (kDebugMode) {
            print(
              "Backend flow => error: $error",
            );
          }
          widget.config.onError(
            error,
          );
        },
        (success) {
          if (kDebugMode) {
            print(
              "Backend flow => Payment Captured: $success",
            );
          }
        },
      );
    }

    final v2 = services as PaypalServicesV2;

    final result = await v2.captureOrder(
      model.orderId!,
      model.accessToken!,
    );

    result.fold(
      (error) => widget.config.onError(error),
      (success) {
        widget.config.onUserPayment(
          success,
          model,
        );
      },
    );
  }
}
