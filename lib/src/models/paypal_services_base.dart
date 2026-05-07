import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/functions/paypal_safe_api_call.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_payment_model.dart';
import 'package:flutter_paypal_payment_checkout_v2/src/models/paypal_shared_models.dart';

/// Base class for the PayPal V2 service implementation.
///
/// This class handles:
/// - Inline credential validation (security warnings for production).
/// - Access token retrieval (backend-provided or local sandbox flow).
/// - Common initialization logic used before creating PayPal orders.
/// - Shared configuration: clientId, secretKey, sandboxMode.
///
/// Concrete implementations must override:
///   `createPaypalPayment()`
///
/// Notes on security:
/// - Passing clientId/secretKey inside the mobile app is **only safe for sandbox**.
/// - For production: always use a backend to generate access tokens and create orders.
abstract class PaypalServicesBase {
  /// PayPal REST client ID (only allowed inline in sandbox).
  final String? clientId;

  /// PayPal REST secret key (insecure to include in production builds).
  final String? secretKey;

  /// Whether the service uses PayPal sandbox mode.
  final bool sandboxMode;

  /// Overrides the security check allowing inline credentials in production.
  ///
  /// ⚠️ Only use this for debugging — never ship to users.
  final bool overrideInsecureClientCredentials;

  /// Optional function that retrieves an access token from your backend.
  ///
  /// When provided, `getAccessToken()` skips the local OAuth call entirely.
  final PayPalGetAccessToken? getAccessTokenFunction;

  const PaypalServicesBase({
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
    required this.getAccessTokenFunction,
    this.overrideInsecureClientCredentials = false,
  });

  /// Base URL for PayPal REST API depending on sandbox mode.
  String get baseUrl => sandboxMode
      ? "https://api-m.sandbox.paypal.com"
      : "https://api-m.paypal.com";

  /// Verifies that inline credentials are not used in a production environment.
  ///
  /// Returns:
  /// - `PayPalErrorModel` when credentials are unsafe.
  /// - `null` when everything is safe or allowed.
  ///
  /// This protects developers from shipping PayPal client secrets inside apps.
  PayPalErrorModel? validateInlineCredentials() {
    final hasInlineCredentials = (clientId != null && clientId!.isNotEmpty) ||
        (secretKey != null && secretKey!.isNotEmpty);

    if (!sandboxMode &&
        !overrideInsecureClientCredentials &&
        hasInlineCredentials) {
      return PayPalErrorModel(
        error: "INSECURE_CLIENT_CREDENTIALS",
        message:
            "You are passing clientId / secretKey directly into the app while not in sandboxMode.\n\n"
            "This is NOT safe for production: anyone can decompile the app and steal your PayPal keys.\n"
            "Recommended production setup:\n"
            "- Move all PayPal calls (access token, create order, capture) to your backend.\n"
            "- Use the `approvalUrl` callback so the client only receives the checkout URL.",
        key: "INSECURE_CLIENT_CREDENTIALS",
        code: 400,
      );
    }

    return null;
  }

  /// Retrieves a PayPal access token used for order creation.
  ///
  /// Two paths are supported:
  ///
  /// **1. Backend-provided access token**
  /// - No HTTP calls done here.
  /// - Most secure and recommended for production.
  ///
  /// **2. Local client_credentials OAuth flow**
  /// - Only allowed in sandbox.
  /// - Uses basic authentication with clientId:secretKey.
  ///
  /// Returns:
  /// - `Right(PayPalAccessTokenModel)` on success.
  /// - `Left(PayPalErrorModel)` on any failure.
  Future<Either<PayPalErrorModel, PayPalAccessTokenModel>>
      getAccessToken() async {
    // Backend-provided access token (secure)
    if (getAccessTokenFunction != null) {
      try {
        final accessToken = await getAccessTokenFunction!();
        return Right(
          PayPalAccessTokenModel(
            accessToken: accessToken,
            message: "Success",
            key: "ACCESS_TOKEN_SUCCESS",
            code: 200,
          ),
        );
      } catch (e) {
        return Left(
          PayPalErrorModel(
            error: e.toString(),
            message: "Unable to retrieve access token from backend.",
            key: "BACKEND_ACCESS_TOKEN_ERROR",
            code: 500,
          ),
        );
      }
    }

    // Local OAuth flow (sandbox/testing only)
    final authToken = base64.encode(
      utf8.encode("$clientId:$secretKey"),
    );

    final result = await payPalSafeApiCall(
      () => Dio().post(
        '$baseUrl/v1/oauth2/token?grant_type=client_credentials',
        options: Options(
          headers: {
            'Authorization': 'Basic $authToken',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      ),
      networkErrorKey: "PAYPAL_CREDENTIALS_ERROR",
      networkErrorMessage: "Your PayPal credentials seem incorrect",
      unknownErrorKey: "ACCESS_TOKEN_NETWORK_ERROR",
      unknownErrorMessage: "Unable to proceed, check your internet connection.",
    );

    return result.fold(
      (error) => Left(error),
      (response) {
        final token = response.data["access_token"];

        return Right(
          PayPalAccessTokenModel(
            accessToken: token,
            message: "Success",
            key: "ACCESS_TOKEN_SUCCESS",
            code: 200,
          ),
        );
      },
    );
  }

  /// Shared initialization logic used before creating a PayPal order.
  ///
  /// Behaves in one of two modes:
  ///
  /// **1. External checkout URL provider**
  /// - If `getApprovalUrl` is provided, no PayPal API call is made here.
  /// - Simply returns your backend-prepared `PaypalPaymentModel`.
  ///
  /// **2. Local order-creation mode**
  /// - Ensures credentials are safe.
  /// - Fetches an access token.
  /// - Validates the PayPal order request.
  /// - Calls `createPaypalPayment` (implemented by subclasses).
  Future<Either<PayPalErrorModel, PaypalPaymentModel>> initialize({
    required PayPalGetCheckOutUrl? getApprovalUrl,
    required PayPalOrderRequestBase? payPalOrder,
  }) async {
    // Backend-controlled checkout URL
    if (getApprovalUrl != null) {
      final checkoutUrl = await getApprovalUrl();
      return checkoutUrl;
    }

    // Validate credentials when executing local API calls
    final insecureError = validateInlineCredentials();
    if (insecureError != null) {
      return Left(insecureError);
    }

    // Fetch access token
    final tokenResponse = await getAccessToken();
    return await tokenResponse.fold(
      (failure) => Left(failure),
      (accessTokenModel) async {
        // Order must be provided
        if (payPalOrder == null) {
          return Left(
            PayPalErrorModel(
              error: "PayPal order cannot be null.",
              message: "PayPal order cannot be null.",
              key: "NULL_ORDER",
              code: 400,
            ),
          );
        }

        // Validate order content
        if (payPalOrder.isEmpty) {
          return Left(
            PayPalErrorModel(
              error: "Purchase Units cannot be empty.",
              message: "Purchase Units cannot be empty.",
              key: "EMPTY_PURCHASE_UNITS",
              code: 400,
            ),
          );
        }

        // Create order via subclass implementation
        final createPaypalPaymentResponse = await createPaypalPayment(
          payPalOrder: payPalOrder,
          accessToken: accessTokenModel.accessToken,
        );

        return createPaypalPaymentResponse.fold(
          (failure) => Left(failure),
          (paymentModel) => Right(paymentModel),
        );
      },
    );
  }

  /// Must be overridden by the V2 service implementation.
  ///
  /// Responsible for:
  /// - Sending the order creation request to PayPal.
  /// - Returning a `PaypalPaymentModel` that contains:
  ///     - approvalUrl
  ///     - orderId
  ///     - accessToken
  ///
  /// Returns:
  /// - `Right(PaypalPaymentModel)` on success.
  /// - `Left(PayPalErrorModel)` on failure.
  Future<Either<PayPalErrorModel, PaypalPaymentModel>> createPaypalPayment({
    required PayPalOrderRequestBase payPalOrder,
    required String accessToken,
  });
}
