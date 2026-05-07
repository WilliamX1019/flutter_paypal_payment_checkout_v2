/// Flutter PayPal Payment Checkout (V2).
///
/// This library exposes a single high-level widget:
/// [PaypalCheckoutView]
///
/// It handles:
/// - Creating a PayPal order (via V2 Orders API)
/// - Rendering the approval page in an in-app webview
/// - Listening to return/cancel URLs
/// - Capturing the payment
/// - Returning the result via callbacks
///
/// For a UI-free approach, use [PaypalCheckoutController] directly.
library flutter_paypal_payment_checkout_v2;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/paypal_checkout_controller.dart';

import 'models/paypal_payment_model.dart'
    show PaypalCheckoutConfig;


/// Main checkout widget that handles the entire PayPal flow.
///
/// This widget:
/// - Initializes the PayPal V2 API service.
/// - Either:
///   - Uses a backend-provided [approvalUrl], **or**
///   - Creates the payment/order directly from the client.
/// - Opens an in-app webview to show the PayPal approval page.
/// - Listens for success/cancel redirects using return/cancel URLs.
/// - Executes/captures the payment for client-side flows.
/// - Returns the result to [onUserPayment], [onCancel], or [onError].
///
/// For a UI-free approach, use [PaypalCheckoutController] directly with
/// your own WebView.
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
  /// The headless controller that manages all PayPal logic.
  late final PaypalCheckoutController _controller;

  /// Web loading progress (0.0–1.0).
  double progress = 0;

  /// Controller for the embedded InAppWebView.
  late InAppWebViewController webView;

  @override
  void initState() {
    super.initState();
    _controller = PaypalCheckoutController(config: widget.config);
    _initializePayment();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Initializes the PayPal flow via the controller.
  Future<void> _initializePayment() async {
    final result = await _controller.initialize();

    result.fold(
      (error) => widget.config.onError(error),
      (paymentModel) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // While payment/order is initializing → show a loading screen.
    if (!_controller.isInitialized) {
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

    final paymentModel = _controller.paymentModel!;

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

              final match = _controller.matchUrl(urlStr);

              if (match == PayPalUrlMatch.returnUrl) {
                await _controller.handleReturnUrl(url);
                return NavigationActionPolicy.CANCEL;
              }

              if (match == PayPalUrlMatch.cancelUrl) {
                _controller.handleCancel();
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            initialUrlRequest: URLRequest(
              url: WebUri(paymentModel.approvalUrl),
            ),
            onWebViewCreated: (controller) {
              webView = controller;
            },
            onCloseWindow: (controller) {
              _controller.handleCancel();
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
}
