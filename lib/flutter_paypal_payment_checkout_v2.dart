/// Flutter PayPal Payment Checkout (V1 + V2)
///
/// This is the main export file for the package.
/// It provides:
///
/// - The high-level `PaypalCheckoutView` widget
/// - Base models and shared utilities
/// - PayPal Payments API **V1** (legacy)
/// - PayPal Orders API **V2** (recommended)
///
/// Developers typically only import:
///
/// ```dart
/// import 'package:flutter_paypal_payment_checkout_v2/flutter_paypal_payment_checkout_v2.dart';
/// ```
///
/// After that they can use:
/// - `PaypalCheckoutView`
/// - All V1/V2 order, item, and amount models
/// - All enums for behavior customization
///
/// This file serves as the "public surface" of the SDK.
library flutter_paypal_payment_checkout_v2;

// -----------------------------------------------------------------------------
// MAIN CHECKOUT VIEW
// -----------------------------------------------------------------------------

/// Provides:
/// - The in-app PayPal approval webview
/// - Order creation (client or backend-driven)
/// - Execution / capture flow
/// - `onSuccess`, `onError`, `onCancel` callbacks
export 'src/paypal_checkout_view.dart';

// -----------------------------------------------------------------------------
// SHARED UTILITIES & BASE CLASSES
// -----------------------------------------------------------------------------

/// Shared safe API wrapper for consistent error handling.
export 'src/functions/paypal_safe_api_call.dart';

/// Models representing errors, success responses, tokens, base structures, etc.
export 'src/models/paypal_payment_model.dart';

/// Base service class that unifies behavior between V1 & V2 implementations.
export 'src/models/paypal_services_base.dart';

/// Shared typedefs, constants, base request class, and callbacks.
export 'src/models/paypal_shared_models.dart';

// -----------------------------------------------------------------------------
// PAYPAL V1 API (Legacy Payments API)
// -----------------------------------------------------------------------------

/// Service implementing PayPal Payments V1:
/// - `/v1/payments/payment`
/// - `execute` flow
export 'src/v1/paypal_service_v1.dart';

// V1 Enums
export 'src/v1/enums/paypal_allowed_payment_method_v1.dart';
export 'src/v1/enums/paypal_order_intent_v1.dart';

// V1 Models (items, amounts, transactions, shipping, order request)
export 'src/v1/models/paypal_transaction_v1.dart';
export 'src/v1/models/paypal_transaction_v1_amount.dart';
export 'src/v1/models/paypal_transaction_v1_item.dart';
export 'src/v1/models/paypal_order_request_v1.dart';
export 'src/v1/models/paypal_shipping_address_v1.dart';

// -----------------------------------------------------------------------------
// PAYPAL V2 API (Recommended Orders API)
// -----------------------------------------------------------------------------

/// Service implementing PayPal Orders V2:
/// - `/v2/checkout/orders`
/// - `/v2/checkout/orders/{id}/capture`
export 'src/v2/paypal_service_v2.dart';

// V2 Enums (intent, user action, item category, prefs, etc.)
export 'src/v2/enums/paypal_item_category_v2.dart';
export 'src/v2/enums/paypal_landing_page_v2.dart';
export 'src/v2/enums/paypal_order_intent_v2.dart';
export 'src/v2/enums/paypal_payment_method_preference_v2.dart';
export 'src/v2/enums/paypal_shipping_preference_v2.dart';
export 'src/v2/enums/paypal_user_action_v2.dart';

// V2 Models (amounts, items, shipping)
export 'package:flutter_paypal_payment_checkout_v2/src/v2/models/paypal_amount_v2.dart';
export 'package:flutter_paypal_payment_checkout_v2/src/v2/models/paypal_shipping_address_v2.dart';
export 'package:flutter_paypal_payment_checkout_v2/src/v2/models/paypal_transaction_item_v2.dart';

// Core V2 models (payment source, purchase unit, order request)
export 'src/v2/models/paypal_payment_source_v2.dart';
export 'src/v2/models/paypal_order_request_v2.dart';
export 'src/v2/models/paypal_purchase_unit_v2.dart';

// V2 Response models (capture response, payer)
export 'src/v2/models/paypal_capture_response_v2.dart';
export 'src/v2/models/paypal_payer_v2.dart';

// -----------------------------------------------------------------------------
// EXTERNAL UTILITIES
// -----------------------------------------------------------------------------

/// Exporting dartz so developers can access:
/// - Either
/// - Left
/// - Right
/// - Unit
/// - Option
///
/// Example usage:
/// ```dart
/// return Right(value);
/// ```
export 'package:dartz/dartz.dart';
