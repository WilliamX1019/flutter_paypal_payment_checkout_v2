/// Represents a shipping address for **PayPal Orders V2**.
///
/// Maps to:
/// `purchase_units[].shipping`
///
/// Example PayPal JSON:
/// ```json
/// {
///   "name": { "full_name": "John Doe" },
///   "address": {
///     "address_line_1": "123 Main St",
///     "address_line_2": "Apt 5",
///     "admin_area_1": "CA",
///     "admin_area_2": "San Francisco",
///     "postal_code": "94107",
///     "country_code": "US"
///   }
/// }
/// ```
class PayPalShippingAddressV2 {
  /// Full name of recipient.
  final String name;

  /// Address line 1 (street, building number).
  final String addressLine1;

  /// Optional address line 2.
  final String? addressLine2;

  /// City or locality.
  final String city;

  /// State, province, or region.
  final String state;

  /// ZIP or postal code.
  final String postalCode;

  /// ISO country code (e.g., "US", "CA", "EG").
  final String countryCode;

  PayPalShippingAddressV2({
    required this.name,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.countryCode,
  });

  /// Creates a [PayPalShippingAddressV2] from PayPal API response JSON.
  ///
  /// Expected input format (from `purchase_units[].shipping`):
  /// ```json
  /// {
  ///   "name": { "full_name": "John Doe" },
  ///   "address": {
  ///     "address_line_1": "123 Main St",
  ///     "address_line_2": "Apt 5",
  ///     "admin_area_2": "San Jose",
  ///     "admin_area_1": "CA",
  ///     "postal_code": "95131",
  ///     "country_code": "US"
  ///   }
  /// }
  /// ```
  factory PayPalShippingAddressV2.fromJson(Map<String, dynamic> json) {
    final nameObj = json['name'] as Map<String, dynamic>?;
    final address = json['address'] as Map<String, dynamic>? ?? {};

    return PayPalShippingAddressV2(
      name: nameObj?['full_name'] as String? ?? '',
      addressLine1: address['address_line_1'] as String? ?? '',
      addressLine2: address['address_line_2'] as String?,
      city: address['admin_area_2'] as String? ?? '',
      state: address['admin_area_1'] as String? ?? '',
      postalCode: address['postal_code'] as String? ?? '',
      countryCode: address['country_code'] as String? ?? '',
    );
  }

  /// Converts this address into PayPal V2 JSON format.
  Map<String, dynamic> toJson() => {
        "name": {
          "full_name": name,
        },
        "address": {
          "address_line_1": addressLine1,
          if (addressLine2 != null) "address_line_2": addressLine2,
          "admin_area_2": city,
          "admin_area_1": state,
          "postal_code": postalCode,
          "country_code": countryCode,
        },
      };
}
