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
        shippingPreference: PayPalShippingPreferenceV2.noShipping,
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
          shippingAddress: PayPalShippingAddressV2(
            name: 'John Doe',
            addressLine1: '123 Demo Street',
            addressLine2: 'Suite 100',
            city: 'San Francisco',
            state: 'CA',
            postalCode: '94105',
            countryCode: 'US',
          ),
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
              Navigator.pop(context);
              return const Right<PayPalErrorModel, dynamic>(
                null,
              );
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

  // void startPayPalBackendFlow(BuildContext context, int servicePlanId) async {
  //   final service = PayPalService(DioHelper());
  //
  //   // Open checkout view with backend-driven flow
  //   await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => PaypalCheckoutView<PaypalPaymentModel>(
  //         version: PayPalApiVersion.v2,
  //         sandboxMode: true,
  //         /// Pass a function that fetches the checkout URL and model from your backend
  //         getCheckoutUrl: () async {
  //           final result = await service.createOrder(servicePlanId: servicePlanId);
  //           return result; // Either<PayPalErrorModel, PaypalPaymentModel>
  //         },
  //
  //         onUserPayment: (success, payment) async {
  //           print("Payment approved: ${payment.toJson()}");
  //           print("Capture data: ${success?.data}");
  //
  //           // Capture via backend
  //           final captureResult = await service.captureOrder(orderId: payment.orderId!);
  //           captureResult.fold(
  //                 (failure) => print("Capture failed: ${failure.message}"),
  //                 (_) => print("Payment captured successfully"),
  //           );
  //
  //           return Right<PayPalErrorModel, dynamic>(success?.data);
  //         },
  //
  //         onError: (error) {
  //           print("Checkout error: ${error.message}");
  //           Navigator.pop(context);
  //         },
  //
  //         onCancel: () {
  //           print("Payment cancelled by user");
  //           Navigator.pop(context);
  //         },
  //       ),
  //     ),
  //   );
  // }

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
