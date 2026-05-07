import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment_checkout_v2/flutter_paypal_payment_checkout_v2.dart';

void main() {
  runApp(const PaypalPaymentDemo());
}

class PaypalPaymentDemo extends StatelessWidget {
  const PaypalPaymentDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PayPal Payment Demo',
      debugShowCheckedModeBanner: false,
      home: PaypalDemoHome(),
    );
  }
}

class PaypalDemoHome extends StatelessWidget {
  const PaypalDemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayPal Payment Demo'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HelpCard(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _startV2MobileFlow(context),
              child: const Text('Pay with PayPal (V2 – Checkout Orders API)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _startV1Flow(context),
              child: const Text('Pay with PayPal (V1 – Payments API, legacy)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _startPayPalBackendFlow(context, 42),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay with PayPal (V2 – Backend Flow)'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- V2 EXAMPLE ----------------
  void _startV2MobileFlow(BuildContext context) {
    // Build a simple V2 order with 1 purchase unit
    final order = PayPalOrderRequestV2(
      intent: PayPalOrderIntentV2.capture,
      paymentSource: PayPalPaymentSourceV2(
        paymentMethodPreference:
            PayPalPaymentMethodPreferenceV2.immediatePaymentRequired,
        // 👇 Use getFromFile to let PayPal provide the buyer's saved address
        //    Use noShipping for digital goods / services
        //    Use setProvidedAddress to lock a specific address
        shippingPreference: PayPalShippingPreferenceV2.getFromFile,
        // Where PayPal should redirect the user after they approve or cancel
        // returnUrl: "https://example.com/paypal/return",
        // cancelUrl: "https://example.com/paypal/cancel",
        // Optional:
        // landingPage: PayPalLandingPageV2.noPreference,
        // userAction: PayPalUserActionV2.payNow,
      ),
      purchaseUnits: [
        PayPalPurchaseUnitV2(
          // invoiceId: 'INV-123456',
          amount: PayPalAmountV2(
            currency: 'USD',
            value: 100.0, // total amount
            itemTotal: 100.0, // sum of items
            taxTotal: 0.0, // total tax
          ),
          items: [
            PaypalTransactionV2Item(
              name: 'Apple',
              description: 'Fresh red apples',
              quantity: 2,
              unitAmount: 50.0,
              // 2 * 50 = 100
              currency: 'USD',
              category: PayPalItemCategoryV2.physicalGoods,
              sku: 'SKU_APPLE',
              imageUrl: 'https://example.com/images/apple.png',
              url: 'https://example.com/products/apple',
              upcCode: '123456789012',
              upcType: 'UPC_A',
            ),
          ],
          // 👇 When using getFromFile, you can omit shippingAddress
          //    PayPal will use the buyer's address from their account.
          //    Uncomment below to pre-fill / lock a specific address:
          // shippingAddress: PayPalShippingAddressV2(
          //   name: 'John Doe',
          //   addressLine1: '123 Demo Street',
          //   addressLine2: 'Suite 100',
          //   city: 'San Francisco',
          //   state: 'CA',
          //   postalCode: '94105',
          //   countryCode: 'US',
          // ),
        ),
      ],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaypalCheckoutView(
          config: PaypalCheckoutConfig(
            version: PayPalApiVersion.v2,
            // 👇 In production, prefer getting approvalUrl / accessToken from backend
            getAccessToken: null,
            // using clientId/secret (sandbox ONLY)
            approvalUrl: null,

            sandboxMode: true,
            clientId: 'ONLY FOR SANDBOX (TESTING PURPOSES ONLY)',
            secretKey: 'ONLY FOR SANDBOX (TESTING PURPOSES ONLY)',

            payPalOrder: order,
            onUserPayment: (success, payment) async {
              log('V2 onSuccess payment: ${payment.toJson()}');
              log('V2 onSuccess capture data: ${success?.data}');

              // 👇 Parse the capture response to get structured shipping address
              if (success != null && success.data is Map<String, dynamic>) {
                final capture = PayPalCaptureResponseV2.fromJson(
                  success.data as Map<String, dynamic>,
                );

                // Shipping address from buyer's PayPal account
                final shipping = capture.shippingAddress;
                if (shipping != null) {
                  log('📦 Shipping to: ${shipping.name}');
                  log('   ${shipping.addressLine1}');
                  if (shipping.addressLine2 != null) {
                    log('   ${shipping.addressLine2}');
                  }
                  log('   ${shipping.city}, ${shipping.state} ${shipping.postalCode}');
                  log('   ${shipping.countryCode}');
                }

                // Payer info
                final payer = capture.payer;
                if (payer != null) {
                  log('👤 Payer: ${payer.fullName} (${payer.emailAddress})');
                }

                // Capture details
                log('💰 Captured: ${capture.captureAmount} ${capture.captureCurrency}');
                log('   PayPal fee: ${capture.paypalFeeAmount} ${capture.paypalFeeCurrency}');
                log('   Net: ${capture.netAmount} ${capture.netCurrency}');
              }

              Navigator.pop(context);
              return const Right<PayPalErrorModel, dynamic>(null);
            },
            onError: (error) {
              log('V2 onError: ${error.message} (${error.key})');
              Navigator.pop(context);
            },
            onCancel: () {
              log('V2 cancelled by user');
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  // ---------------- V2 BACKEND FLOW EXAMPLE ----------------
  /// Production-recommended flow:
  /// 1. Client calls YOUR backend to create a PayPal order.
  /// 2. Backend returns a [PaypalPaymentModel] with the approvalUrl.
  /// 3. SDK opens the approval page in a WebView.
  /// 4. After user approval, [onUserPayment] is called with success=null
  ///    (since the SDK doesn't hold the accessToken in backend flow).
  /// 5. Client calls YOUR backend to capture the order.
  void _startPayPalBackendFlow(BuildContext context, int servicePlanId) async {
    // Replace with your actual backend service
    final service = _DemoPayPalBackendService();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          config: PaypalCheckoutConfig(
            version: PayPalApiVersion.v2,
            sandboxMode: true,

            // Backend flow: client does NOT need credentials
            clientId: null,
            secretKey: null,
            getAccessToken: null,

            // Backend flow: order is created server-side, not needed here
            payPalOrder: null,

            /// 👇 Core of backend flow:
            /// This callback fetches the checkout URL from YOUR backend.
            /// The backend creates the PayPal order and returns a PaypalPaymentModel.
            approvalUrl: () async {
              final result = await service.createOrder(
                servicePlanId: servicePlanId,
              );
              return result; // Either<PayPalErrorModel, PaypalPaymentModel>
            },

            onUserPayment: (success, payment) async {
              log('Backend flow: payment approved: ${payment.toJson()}');
              // success is null in backend flow (SDK didn't capture)
              // → Call YOUR backend to capture the order
              final captureResult = await service.captureOrder(
                orderId: payment.orderId!,
              );
              captureResult.fold(
                (failure) {
                  log('Capture failed: ${failure.message}');
                  Navigator.pop(context);
                },
                (captureData) {
                  log('Payment captured successfully: $captureData');
                  Navigator.pop(context);
                },
              );
              return captureResult;
            },

            onError: (error) {
              log('Backend flow error: ${error.message} (${error.key})');
              Navigator.pop(context);
            },

            onCancel: () {
              log('Backend flow cancelled by user');
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  // ---------------- V1 EXAMPLE ----------------
  void _startV1Flow(BuildContext context) {
    // Build a V1-style order with transactions/items
    final transaction = PaypalTransactionV1(
      amount: PaypalTransactionV1Amount(
        subTotal: 100.0,
        tax: 0.0,
        total: 100.0,
        // total = subtotal + tax + shipping + handlingFee - shippingDiscount + insurance
        shipping: 0.0,
        handlingFee: 0.0,
        shippingDiscount: 0.0,
        insurance: 0.0,
        currency: 'USD',
      ),
      description: "V1 demo – apples & pineapples",
      custom: "EXAMPLE-USER-ID",
      items: [
        PaypalTransactionV1Item(
          name: "Apple",
          description: "Fresh apples",
          quantity: 4,
          price: 10.0,
          tax: 0.0,
          sku: "SKU_APPLE",
          currency: "USD",
        ),
        PaypalTransactionV1Item(
          name: "Pineapple",
          description: "Fresh pineapples",
          quantity: 5,
          price: 12.0,
          tax: 0.0,
          sku: "SKU_PINEAPPLE",
          currency: "USD",
        ),
      ],
      shippingAddress: PayPalShippingAddressV1(
        recipientName: "John Doe",
        line1: "123 Demo Street",
        line2: "Suite 100",
        city: "San Francisco",
        postalCode: '94105',
        countryCode: 'US',
        phone: '+201111111111',
        state: 'CA',
      ),
      // optional
      // invoiceNumber: "123456789",
      // payPalAllowedPaymentMethod: PayPalAllowedPaymentMethodV1.immediatePay,
      // softDescriptor: "123456789",
    );

    final order = PayPalOrderRequestV1(
      intent: PayPalOrderIntentV1.sale,
      // paymentMethod: "paypal",
      transactions: [transaction],
      // Where PayPal should redirect the user after they approve or cancel
      // returnUrl: "https://example.com/paypal/return",
      // cancelUrl: "https://example.com/paypal/cancel",
      noteToPayer: "Contact us for any questions on your order.",
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaypalCheckoutView(
          config: PaypalCheckoutConfig(
            version: PayPalApiVersion.v1,
            // 👇 In production, prefer backend access token / approvalUrl
            getAccessToken: null,
            // using clientId/secret (sandbox ONLY)
            approvalUrl: null,

            sandboxMode: true,
            clientId: 'ONLY FOR SANDBOX (TESTING PURPOSES ONLY)',
            secretKey: 'ONLY FOR SANDBOX (TESTING PURPOSES ONLY)',

            payPalOrder: order,
            onUserPayment: (success, payment) async {
              log('V1 onSuccess payment: ${payment.toJson()}');
              log('V1 onSuccess execute data: ${success?.data}');
              Navigator.pop(context);
              return const Right<PayPalErrorModel, dynamic>(
                null,
              );
            },
            onError: (error) {
              log('V1 onError: ${error.message} (${error.key})');
              Navigator.pop(context);
            },
            onCancel: () {
              log('V1 cancelled by user');
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------- HELP WIDGET ----------------

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How this demo works",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "• V2 button uses the modern Checkout Orders API (v2). "
              "This is the recommended integration for new apps.\n\n"
              "• V1 button uses the legacy Payments API (v1). "
              "PayPal still supports it for older integrations but it is not recommended for new projects.\n\n"
              "Security notes:\n"
              "- In production, NEVER ship clientId/secret inside the app.\n"
              "- Your backend should call PayPal (create order/payment, capture/execute) "
              "and send only the approval URL to the client.\n"
              "- `getAccessToken` and `approvalUrl` callbacks are designed for that secure flow.",
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DEMO BACKEND SERVICE (replace with your actual backend API client)
// ---------------------------------------------------------------------------

/// Simulates a backend service that interacts with PayPal on the server side.
///
/// In a real app, replace this class with your actual HTTP client that
/// calls your backend endpoints (e.g., using Dio, http, Retrofit, etc.).
///
/// Your backend should:
/// 1. Create PayPal orders via `POST /v2/checkout/orders`
/// 2. Return the approval URL and order ID to the client
/// 3. Capture orders via `POST /v2/checkout/orders/{id}/capture`
class _DemoPayPalBackendService {
  /// Calls your backend to create a PayPal order.
  ///
  /// Example backend endpoint: `POST /api/paypal/create-order`
  /// Request body: `{ "service_plan_id": 42 }`
  /// Response: `{ "order_id": "...", "approval_url": "https://..." }`
  Future<Either<PayPalErrorModel, PaypalPaymentModel>> createOrder({
    required int servicePlanId,
  }) async {
    // TODO: Replace with actual backend API call, e.g.:
    //
    // final response = await dio.post(
    //   'https://your-backend.com/api/paypal/create-order',
    //   data: {'service_plan_id': servicePlanId},
    // );
    //
    // if (response.statusCode == 200) {
    //   final data = response.data;
    //   return Right(PaypalPaymentModel(
    //     orderId: data['order_id'],
    //     approvalUrl: data['approval_url'],
    //     returnURL: data['return_url'] ?? defaultReturnURL,
    //     cancelURL: data['cancel_url'] ?? defaultCancelURL,
    //     accessToken: null,  // Backend holds the token, not the client
    //     executeUrl: null,   // V2 doesn't use execute URL
    //     status: data['status'],
    //     message: 'Order created',
    //     key: 'ORDER_CREATED',
    //     code: 200,
    //   ));
    // } else {
    //   return Left(PayPalErrorModel(
    //     error: response.data,
    //     message: 'Failed to create order',
    //     key: 'BACKEND_CREATE_ORDER_FAILED',
    //     code: response.statusCode ?? 500,
    //   ));
    // }

    // Simulated response for demo purposes:
    return Left(
      PayPalErrorModel(
        error: 'Demo mode: no real backend configured',
        message:
            'Replace _DemoPayPalBackendService with your actual backend service.\n'
            'See the comments in the source code for implementation guidance.',
        key: 'DEMO_NOT_CONFIGURED',
        code: 501,
      ),
    );
  }

  /// Calls your backend to capture a previously approved PayPal order.
  ///
  /// Example backend endpoint: `POST /api/paypal/capture-order`
  /// Request body: `{ "order_id": "..." }`
  /// Response: `{ "status": "COMPLETED", "capture_id": "..." }`
  Future<Either<PayPalErrorModel, dynamic>> captureOrder({
    required String orderId,
  }) async {
    // TODO: Replace with actual backend API call, e.g.:
    //
    // final response = await dio.post(
    //   'https://your-backend.com/api/paypal/capture-order',
    //   data: {'order_id': orderId},
    // );
    //
    // if (response.statusCode == 200) {
    //   return Right(response.data);
    // } else {
    //   return Left(PayPalErrorModel(
    //     error: response.data,
    //     message: 'Failed to capture order',
    //     key: 'BACKEND_CAPTURE_ORDER_FAILED',
    //     code: response.statusCode ?? 500,
    //   ));
    // }

    return Left(
      PayPalErrorModel(
        error: 'Demo mode: no real backend configured',
        message: 'Replace with your actual capture API call',
        key: 'DEMO_NOT_CONFIGURED',
        code: 501,
      ),
    );
  }
}
