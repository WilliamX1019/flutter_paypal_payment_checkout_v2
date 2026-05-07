import 'package:flutter_paypal_payment_checkout_v2/src/v2/models/paypal_payer_v2.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/v2/models/paypal_shipping_address_v2.dart';

/// Structured representation of a PayPal **Orders V2** capture response.
///
/// Provides type-safe access to the most commonly needed fields from
/// the raw PayPal capture/order response, including:
/// - Order ID and status
/// - Payer information (name, email, PayPal ID)
/// - Shipping address (from buyer's PayPal account or provided)
/// - Capture details (capture ID, amount, fees)
///
/// Usage:
/// ```dart
/// onUserPayment: (success, payment) async {
///   if (success != null) {
///     final capture = PayPalCaptureResponseV2.fromJson(success.data);
///     print('Shipping: ${capture.shippingAddress?.city}');
///     print('Payer: ${capture.payer?.fullName}');
///   }
/// }
/// ```
///
/// The [rawData] field always contains the complete, unmodified PayPal
/// response for accessing any fields not explicitly parsed.
class PayPalCaptureResponseV2 {
  /// PayPal order ID.
  final String? orderId;

  /// Order status (e.g., "COMPLETED", "APPROVED").
  final String? status;

  /// Buyer/payer information.
  final PayPalPayerV2? payer;

  /// Shipping address selected or provided during checkout.
  ///
  /// Available when:
  /// - `shipping_preference` is `GET_FROM_FILE` (from buyer's PayPal account)
  /// - `shipping_preference` is `SET_PROVIDED_ADDRESS` (merchant-provided)
  ///
  /// Will be `null` when `shipping_preference` is `NO_SHIPPING`.
  final PayPalShippingAddressV2? shippingAddress;

  /// Capture ID from PayPal (unique identifier for this capture).
  final String? captureId;

  /// Captured amount value (as string, e.g., "100.00").
  final String? captureAmount;

  /// Captured amount currency code (e.g., "USD").
  final String? captureCurrency;

  /// Capture status (e.g., "COMPLETED").
  final String? captureStatus;

  /// PayPal fee amount (as string, e.g., "3.00").
  final String? paypalFeeAmount;

  /// PayPal fee currency code.
  final String? paypalFeeCurrency;

  /// Net amount after PayPal fee (as string, e.g., "97.00").
  final String? netAmount;

  /// Net amount currency code.
  final String? netCurrency;

  /// Payment source info from PayPal (name, email, account_id, etc.).
  final PayPalPayerV2? paymentSourcePayer;

  /// The complete, unmodified PayPal response JSON.
  ///
  /// Use this to access any fields not explicitly parsed by this model.
  final Map<String, dynamic> rawData;

  PayPalCaptureResponseV2({
    this.orderId,
    this.status,
    this.payer,
    this.shippingAddress,
    this.captureId,
    this.captureAmount,
    this.captureCurrency,
    this.captureStatus,
    this.paypalFeeAmount,
    this.paypalFeeCurrency,
    this.netAmount,
    this.netCurrency,
    this.paymentSourcePayer,
    this.rawData = const {},
  });

  /// Parses a PayPal capture (or order) response into a structured model.
  ///
  /// Handles both capture and authorize response formats.
  ///
  /// Example capture response:
  /// ```json
  /// {
  ///   "id": "5O190127TN364715T",
  ///   "status": "COMPLETED",
  ///   "payment_source": {
  ///     "paypal": {
  ///       "name": { "given_name": "John", "surname": "Doe" },
  ///       "email_address": "john@example.com",
  ///       "account_id": "QYR5Z8XDVJNXQ"
  ///     }
  ///   },
  ///   "purchase_units": [{
  ///     "shipping": {
  ///       "name": { "full_name": "John Doe" },
  ///       "address": {
  ///         "address_line_1": "2211 N First Street",
  ///         "admin_area_2": "San Jose",
  ///         "admin_area_1": "CA",
  ///         "postal_code": "95131",
  ///         "country_code": "US"
  ///       }
  ///     },
  ///     "payments": {
  ///       "captures": [{
  ///         "id": "3C679366HH908993F",
  ///         "status": "COMPLETED",
  ///         "amount": { "currency_code": "USD", "value": "100.00" },
  ///         "seller_receivable_breakdown": {
  ///           "paypal_fee": { "currency_code": "USD", "value": "3.00" },
  ///           "net_amount": { "currency_code": "USD", "value": "97.00" }
  ///         }
  ///       }]
  ///     }
  ///   }],
  ///   "payer": {
  ///     "name": { "given_name": "John", "surname": "Doe" },
  ///     "email_address": "john@example.com",
  ///     "payer_id": "QYR5Z8XDVJNXQ"
  ///   }
  /// }
  /// ```
  factory PayPalCaptureResponseV2.fromJson(Map<String, dynamic> json) {
    // Parse payer
    final payerJson = json['payer'] as Map<String, dynamic>?;
    final payer = payerJson != null ? PayPalPayerV2.fromJson(payerJson) : null;

    // Parse payment_source.paypal as payer-like info
    final paymentSource = json['payment_source'] as Map<String, dynamic>?;
    final paypalSource = paymentSource?['paypal'] as Map<String, dynamic>?;
    PayPalPayerV2? paymentSourcePayer;
    if (paypalSource != null) {
      paymentSourcePayer = PayPalPayerV2(
        givenName:
            (paypalSource['name'] as Map<String, dynamic>?)?['given_name']
                as String?,
        surname: (paypalSource['name'] as Map<String, dynamic>?)?['surname']
            as String?,
        emailAddress: paypalSource['email_address'] as String?,
        payerId: paypalSource['account_id'] as String?,
      );
    }

    // Parse first purchase unit
    final purchaseUnits = json['purchase_units'] as List<dynamic>?;
    final firstUnit = purchaseUnits?.isNotEmpty == true
        ? purchaseUnits![0] as Map<String, dynamic>
        : null;

    // Parse shipping address
    final shippingJson = firstUnit?['shipping'] as Map<String, dynamic>?;
    final shippingAddress = shippingJson != null
        ? PayPalShippingAddressV2.fromJson(shippingJson)
        : null;

    // Parse capture details (from payments.captures[0])
    final payments = firstUnit?['payments'] as Map<String, dynamic>?;
    final captures = payments?['captures'] as List<dynamic>?;
    final firstCapture = captures?.isNotEmpty == true
        ? captures![0] as Map<String, dynamic>
        : null;

    // Also check authorizations for AUTHORIZE intent
    final authorizations = payments?['authorizations'] as List<dynamic>?;
    final firstAuth = authorizations?.isNotEmpty == true
        ? authorizations![0] as Map<String, dynamic>
        : null;

    final paymentDetail = firstCapture ?? firstAuth;
    final amount = paymentDetail?['amount'] as Map<String, dynamic>?;

    // Parse fee breakdown
    final breakdown =
        paymentDetail?['seller_receivable_breakdown'] as Map<String, dynamic>?;
    final paypalFee = breakdown?['paypal_fee'] as Map<String, dynamic>?;
    final netAmountObj = breakdown?['net_amount'] as Map<String, dynamic>?;

    return PayPalCaptureResponseV2(
      orderId: json['id'] as String?,
      status: json['status'] as String?,
      payer: payer,
      shippingAddress: shippingAddress,
      captureId: paymentDetail?['id'] as String?,
      captureAmount: amount?['value'] as String?,
      captureCurrency: amount?['currency_code'] as String?,
      captureStatus: paymentDetail?['status'] as String?,
      paypalFeeAmount: paypalFee?['value'] as String?,
      paypalFeeCurrency: paypalFee?['currency_code'] as String?,
      netAmount: netAmountObj?['value'] as String?,
      netCurrency: netAmountObj?['currency_code'] as String?,
      paymentSourcePayer: paymentSourcePayer,
      rawData: json,
    );
  }

  /// Converts this response into a JSON map.
  Map<String, dynamic> toJson() => {
        if (orderId != null) 'id': orderId,
        if (status != null) 'status': status,
        if (payer != null) 'payer': payer!.toJson(),
        if (shippingAddress != null) 'shipping': shippingAddress!.toJson(),
        if (captureId != null) 'capture_id': captureId,
        if (captureAmount != null)
          'capture_amount': {
            'currency_code': captureCurrency,
            'value': captureAmount,
          },
        if (captureStatus != null) 'capture_status': captureStatus,
        if (paypalFeeAmount != null)
          'paypal_fee': {
            'currency_code': paypalFeeCurrency,
            'value': paypalFeeAmount,
          },
        if (netAmount != null)
          'net_amount': {
            'currency_code': netCurrency,
            'value': netAmount,
          },
      };

  @override
  String toString() => 'PayPalCaptureResponseV2('
      'orderId: $orderId, '
      'status: $status, '
      'payer: $payer, '
      'shipping: ${shippingAddress?.city}, ${shippingAddress?.countryCode}, '
      'captureId: $captureId, '
      'amount: $captureAmount $captureCurrency)';
}
