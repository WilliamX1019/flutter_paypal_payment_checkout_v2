import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/functions/paypal_safe_api_call.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_payment_model.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_services_base.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_shared_models.dart';

import 'models/paypal_order_request_v2.dart';

/// PayPal Orders API V2 integration layer.
///
/// This library provides a concrete implementation of [PaypalServicesBase]
/// that talks to the modern **PayPal Orders V2 API**:
///
/// - `POST /v2/checkout/orders`          → Create order
/// - `POST /v2/checkout/orders/{id}/capture` → Capture an approved order
/// Concrete PayPal service for the **Orders API V2**.
///
/// Extends [PaypalServicesBase] and implements:
///
/// - [createPaypalPayment] to create an order
/// - [captureOrder] to capture a previously approved order
///
/// This implementation:
/// - Uses the shared [payPalSafeApiCall] wrapper for consistent error handling.
/// - Extracts the `approve` / `payer-action` link from the V2 response.
/// - Wraps results into [PaypalPaymentModel] and [PayPalSuccessPaymentModel].
class PaypalServicesV2 extends PaypalServicesBase {
  PaypalServicesV2({
    required String? clientId,
    required String? secretKey,
    required bool sandboxMode,
    required PayPalGetAccessToken? getAccessTokenFunction,
    bool overrideInsecureClientCredentials = false,
  }) : super(
          clientId: clientId,
          secretKey: secretKey,
          sandboxMode: sandboxMode,
          getAccessTokenFunction: getAccessTokenFunction,
          overrideInsecureClientCredentials: overrideInsecureClientCredentials,
        );

  /// Creates a PayPal **Orders V2** checkout order.
  ///
  /// Calls:
  /// ```http
  /// POST /v2/checkout/orders
  /// Authorization: Bearer {accessToken}
  /// Content-Type: application/json
  /// ```
  ///
  /// Steps:
  /// 1. Casts [payPalOrder] to [PayPalOrderRequestV2].
  /// 2. Sends the order payload to `/v2/checkout/orders`.
  /// 3. Parses the `links` array to find the first link with:
  ///    - `rel = "approve"` or
  ///    - `rel = "payer-action"`.
  /// 4. Validates presence of the approval URL.
  /// 5. Returns:
  ///    - `Right(PaypalPaymentModel)` with:
  ///       - `approvalUrl`
  ///       - `orderId`
  ///       - `status`
  ///       - `returnURL` / `cancelURL` from [PayPalPaymentSourceV2]
  ///    - `Left(PayPalErrorModel)` on any error.
  @override
  Future<Either<PayPalErrorModel, PaypalPaymentModel>> createPaypalPayment({
    required PayPalOrderRequestBase payPalOrder,
    required String accessToken,
  }) async {
    payPalOrder as PayPalOrderRequestV2;

    final result = await payPalSafeApiCall(
      () => Dio().post(
        '$baseUrl/v2/checkout/orders',
        data: jsonEncode(payPalOrder.toJson()),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      ),
      networkErrorKey: "NETWORK_ORDER_CREATE_FAILED",
      networkErrorMessage: "Network error: Failed to create order",
      unknownErrorKey: "ORDER_CREATE_FAILED",
      unknownErrorMessage: "Failed to create order",
    );

    return result.fold(
      (error) => Left(error),
      (response) {
        final body = response.data;

        // Links is a List<dynamic>, each is Map<String, dynamic>
        final List<dynamic> linksRaw = body['links'] ?? [];
        Map<String, dynamic>? approvalLink;

        for (final raw in linksRaw) {
          final link = raw as Map<String, dynamic>;
          final rel = link['rel'] as String?;
          if (rel == 'approve' || rel == 'payer-action') {
            approvalLink = link;
            break;
          }
        }

        final href = approvalLink?['href'] as String?;

        if (href == null || href.isEmpty) {
          return Left(
            PayPalErrorModel(
              error: body,
              message:
                  "Missing approval link (no 'approve' or 'payer-action' link found)",
              key: "ORDER_CREATE_NO_APPROVE_LINK",
              code: response.statusCode ?? 500,
            ),
          );
        }

        final orderId = body['id'] as String?;
        final status = body['status'] as String?;

        return Right(
          PaypalPaymentModel(
            orderId: orderId,
            approvalUrl: href,
            message: "Order created successfully",
            key: "ORDER_CREATE_SUCCESS",
            accessToken: accessToken,
            code: response.statusCode ?? 200,
            status: status,
            // Comes from the V2 payment source experience context
            returnURL: payPalOrder.paymentSource.returnUrl,
            cancelURL: payPalOrder.paymentSource.cancelUrl,
          ),
        );
      },
    );
  }

  /// Captures an existing **Orders V2** order.
  ///
  /// This should be called **after** the buyer approves the order using
  /// the approval URL returned from [createPaypalPayment].
  ///
  /// Calls:
  /// ```http
  /// POST /v2/checkout/orders/{orderId}/capture
  /// Authorization: Bearer {accessToken}
  /// Content-Type: application/json
  /// ```
  ///
  /// Returns:
  /// - `Right(PayPalSuccessPaymentModel)` on successful capture.
  /// - `Left(PayPalErrorModel)` on any error (network or API).
  Future<Either<PayPalErrorModel, PayPalSuccessPaymentModel>> captureOrder(
    String orderId,
    String accessToken,
  ) async {
    final result = await payPalSafeApiCall(
      () => Dio().post(
        '$baseUrl/v2/checkout/orders/$orderId/capture',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      ),
      networkErrorKey: "NETWORK_ORDER_CAPTURE_FAILED",
      networkErrorMessage: "Network error: Failed to capture order",
      unknownErrorKey: "ORDER_CAPTURE_FAILED",
      unknownErrorMessage: "Failed to capture order",
    );

    return result.fold(
      (error) => Left(error),
      (response) {
        return Right(
          PayPalSuccessPaymentModel(
            code: response.statusCode ?? 200,
            key: "ORDER_CAPTURE_SUCCESS",
            message: "Order captured successfully",
            data: response.data,
          ),
        );
      },
    );
  }
}
