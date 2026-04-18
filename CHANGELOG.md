---

# Changelog

All notable changes to this project will be documented in this file.

---

## **2.1.1 — 2025-12-12**

### 🧩 Configuration Refactor & DX Improvements

This release focuses on improving developer experience, reducing constructor complexity, and making the checkout flow easier to scale and maintain.

### **✨ New & Updated Features**

#### **Unified Checkout Configuration Model**

* Introduced **`PaypalCheckoutConfig`** as a single source of truth for all checkout parameters.
* Replaced large constructor parameter list in `PaypalCheckoutView` with a single `config` object.
* Significantly improves readability, maintainability, and scalability.

#### **Cleaner Widget API**

* `PaypalCheckoutView` now accepts:

  ```dart
  final PaypalCheckoutConfig config;
  ```

* Eliminates parameter explosion and makes integration more intuitive.

#### **Improved Code Organization**

* Grouped related properties (callbacks, security, UI, order data) into a structured model.
* Prepares the SDK for future enhancements like:

  * Builder patterns
  * Flow-specific validation (backend vs client-driven)
  * Modular configs (UI / Security / Callbacks)

#### **Backward Compatibility Note**

* ⚠️ This is a **breaking change**:

  * Direct constructor parameters have been removed.
  * You must migrate to using `PaypalCheckoutConfig`.

---

### **💡 Why This Matters**

* Easier integration for new developers
* Cleaner and more maintainable codebases
* Reduces human error when passing multiple parameters
* Sets foundation for more advanced API patterns in future releases

---

## **2.1.0 — 2025-12-11**

### 🚀 Backend Flexibility, Async Validation & Error Handling Overhaul

This release introduces powerful improvements to support secure, backend-driven PayPal integrations and richer error handling capabilities.

### **✨ New & Updated Features**

#### **Backend-Driven Checkout Flow**

* Renamed `getApprovalUrl` → **`getCheckoutUrl`**.
* Method now allows developers to fully parse backend responses and return a complete `PaypalPaymentModel` or 'PayPalErrorModel' error.
* Enables secure production workflows where the app *never handles secret keys* or order creation — only the checkout URL.

#### **Asynchronous Payment Callback**

* `onUserPayment` is now **async** and returns `Either<PayPalErrorModel, T>`.
* Developers can run backend validation **after** PayPal approval but **before** the UI completes.
* Returning `Left(PayPalErrorModel(...))` now correctly triggers the error pathway.

#### **Flexible Error Payload Structure**

* `PayPalErrorModel.error` updated from `String` → **`dynamic`**.
* Allows passing backend error objects or full PayPal API responses.

#### **Dartz Re-Exported**

* `dartz` is now re-exported to provide direct access to:

  * `Either`
  * `Left`
  * `Right`
  * `Unit`
* Enables easier construction of custom validation results inside `onUserPayment`.

#### **Localization Completion**

* All remaining keys added to:

  * `errors_keys.json`
  * `messages_keys.json`
* Ensures full localization coverage across success and error flows.

---

## **2.0.9 — 2025-12-10**

### 📄 Documentation Update

* Added **full SDK documentation** across:

  * All V1 & V2 models
  * Enums
  * Services
  * Checkout view
  * Barrel exports
* Improved inline DartDoc everywhere for:

  * Better IDE autocomplete
  * Cleaner pub.dev documentation
  * Easier onboarding for developers
* Ensured consistent formatting and explanations across all classes.

---

## **2.0.7 — 2025-12-10**

### 🛠 Refactor & Stability Improvements

* **Removed all `part` / `part of` files** across V1 and V2 to make the package fully modular and public-API friendly.
* **Replaced parts with standard imports**, fixing issues where models were not accessible when importing the package.
* **Properly exported all V1 & V2 models, enums, and services** from the main library file.
* **Improved package structure** to follow pub.dev best practices for public packages.
* **Stability improvements** for IDE code completion, analyzer warnings, and pub.dev scoring.
* **No breaking API changes** — all models remain the same, just now properly exposed.

---

## 2.0.3 — 2025-12-10

* Added Tharwat to the contributors.

## 2.0.2 — 2025-12-10

* Added a donation link.

**PayPal:**
[https://paypal.me/mazenelgayar](https://paypal.me/mazenelgayar)

**InstaPay:**
[https://ipn.eg/S/mazenel-gayarcib/instapay/0ecfXw](https://ipn.eg/S/mazenel-gayarcib/instapay/0ecfXw)
**Tag:** `mazenel-gayarcib@instapay`

---

# **2.0.1 — 2025-12-10**

🧩 **Unified V1 + V2 API with shared models and services**

This release builds on top of the V2 Orders support and introduces a **unified, version-aware API** that can handle both **PayPal Payments API V1** and **Orders API V2** from a single, clean interface.

### **✨ New Features**

* Added shared abstract base types:

  * `PaypalServicesBase`
  * `PayPalOrderRequestBase`
* New unified checkout widget:

  * `PaypalCheckoutView`
  * Explicit `version: PayPalApiVersion.v1 | PayPalApiVersion.v2`
* Shared payment result model:

  * `PaypalPaymentModel` (used for both V1 & V2 flows)
* Version-aware order models:

  * `PayPalOrderRequestV1` (Payments API v1)
  * `PayPalOrderRequestV2` (Orders API v2)
* Clear client-side handling of:

  * V1 → Execute via `PayerID`
  * V2 → Capture via `orderId`

### **🧪 New Example Screen**

* Demo screen with two buttons:

  * “Pay with PayPal (V2 – Orders API)”
  * “Pay with PayPal (V1 – Payments API)”
* Documentation explaining secure vs insecure workflows.

### **🔒 Safety & Validation**

* Added runtime validation for mismatched order/service versions.
* Centralized checks for empty orders, null payloads, and invalid states.

### **⚠️ Deprecated / Breaking Notes**

* `PaypalCheckoutViewV1` / `V2` now replaced by unified widget.

---

# **2.0.0 — 2025-12-09**

🚀 Major rewrite introducing full PayPal Orders API V2 support.

### **Highlights**

* V2 Orders API: create + capture flow
* Strongly typed models
* New enums for shipping, payment preference, landing page, etc.
* Secure custom URL schemes
* Safer credential validation
* Cleaner webview flow

---

# **1.0.8 — Legacy**

Initial package features.

---