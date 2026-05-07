import 'package:flutter_paypal_payment_checkout_v2/flutter_paypal_payment_checkout_v2.dart';

/// -------------------- ORDER REQUEST --------------------
///
/// Represents a full **PayPal Orders API V2** request.
///
/// This model is used to create an order via:
/// `POST /v2/checkout/orders`
///
/// It includes:
/// - The order intent (`CAPTURE` or `AUTHORIZE`)
/// - The `payment_source.paypal` configuration (checkout behavior)
/// - One or more `purchase_units` (order amount, items, shipping)
///
/// Example minimal JSON:
/// ```json
/// {
///   "intent": "CAPTURE",
///   "payment_source": { ... },
///   "purchase_units": [ ... ]
/// }
/// ```
///
/// For most apps:
/// - Use `intent: CAPTURE`
/// - Provide **1 purchase unit** unless you intentionally need multiple.
class PayPalOrderRequestV2 extends PayPalOrderRequestBase {
  /// Determines whether PayPal should immediately capture the payment
  /// or authorize it for later capture.
  ///
  /// Maps to `intent: "CAPTURE"` or `"AUTHORIZE"`.
  final PayPalOrderIntentV2 intent;

  /// Defines checkout behavior such as:
  /// - Allowed payment methods
  /// - Shipping mode
  /// - Landing page
  /// - User action ("Pay Now" / "Continue")
  /// - Redirect URLs
  ///
  /// Maps to `payment_source.paypal`.
  final PayPalPaymentSourceV2 paymentSource;

  /// The list of purchase units included in this order.
  ///
  /// Each purchase unit contains:
  /// - Amount + breakdown
  /// - Items
  /// - Optional shipping information
  ///
  /// At least one purchase unit is required.
  final List<PayPalPurchaseUnitV2> purchaseUnits;

  PayPalOrderRequestV2({
    this.intent = PayPalOrderIntentV2.capture,
    required this.paymentSource,
    required this.purchaseUnits,
  });

  /// Converts this order into the JSON payload expected by PayPal.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "intent": "CAPTURE",
  ///   "payment_source": { ... },
  ///   "purchase_units": [ { ... } ]
  /// }
  /// ```
  @override
  Map<String, dynamic> toJson() => {
        "intent": intent.value,
        "payment_source": paymentSource.toJson(),
        "purchase_units": purchaseUnits.map((e) => e.toJson()).toList(),
      };

  /// Whether the order has no purchase units.
  @override
  bool get isEmpty => purchaseUnits.isEmpty;
}
