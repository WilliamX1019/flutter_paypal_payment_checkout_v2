/// Represents a PayPal payer (buyer) from the **Orders V2** API response.
///
/// Contains the buyer's identity as returned by PayPal after order approval.
///
/// Example JSON (from capture / order response):
/// ```json
/// {
///   "name": { "given_name": "John", "surname": "Doe" },
///   "email_address": "john@example.com",
///   "payer_id": "QYR5Z8XDVJNXQ",
///   "phone": {
///     "phone_number": { "national_number": "4085551234" }
///   }
/// }
/// ```
class PayPalPayerV2 {
  /// Buyer's first name.
  final String? givenName;

  /// Buyer's last name.
  final String? surname;

  /// Full name (convenience: "$givenName $surname").
  String get fullName =>
      [givenName, surname].where((s) => s != null && s.isNotEmpty).join(' ');

  /// Buyer's email address.
  final String? emailAddress;

  /// PayPal account ID (stable identifier for the buyer).
  final String? payerId;

  /// Buyer's phone number (national format).
  final String? phoneNumber;

  PayPalPayerV2({
    this.givenName,
    this.surname,
    this.emailAddress,
    this.payerId,
    this.phoneNumber,
  });

  /// Creates a [PayPalPayerV2] from the `payer` section of a PayPal response.
  factory PayPalPayerV2.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as Map<String, dynamic>?;
    final phone = json['phone'] as Map<String, dynamic>?;
    final phoneNumber = phone?['phone_number'] as Map<String, dynamic>?;

    return PayPalPayerV2(
      givenName: name?['given_name'] as String?,
      surname: name?['surname'] as String?,
      emailAddress: json['email_address'] as String?,
      payerId: json['payer_id'] as String?,
      phoneNumber: phoneNumber?['national_number'] as String?,
    );
  }

  /// Converts this payer model to a JSON map.
  Map<String, dynamic> toJson() => {
        if (givenName != null || surname != null)
          'name': {
            if (givenName != null) 'given_name': givenName,
            if (surname != null) 'surname': surname,
          },
        if (emailAddress != null) 'email_address': emailAddress,
        if (payerId != null) 'payer_id': payerId,
        if (phoneNumber != null)
          'phone': {
            'phone_number': {'national_number': phoneNumber},
          },
      };

  @override
  String toString() =>
      'PayPalPayerV2(name: $fullName, email: $emailAddress, payerId: $payerId)';
}
