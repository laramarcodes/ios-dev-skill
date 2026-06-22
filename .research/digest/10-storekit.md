# DOMAIN: StoreKit 2 & monetization (in-app purchases, subscriptions, paywalls) for native SwiftUI iPhone/iPad apps

## Orientation
 StoreKit 2 (since iOS 15) is the modern, async/await, Swift-native monetization API and the only one to use for new apps — it replaces the StoreKit 1 delegate/observer model and the old on-device receipt-validation file. Products are loaded with `Product.products(for:)`, bought with `product.purchase(...)`, and every transaction is wrapped in `VerificationResult` (App Store JWS-signed; check `.verified`/`.unverified`). Entitlement state is derived at runtime from `Transaction.currentEntitlements` plus a long-lived `Transaction.updates` listener started at launch — you do NOT parse receipts; for server validation you use the App Store Server API + App Store Server Notifications V2 with the App Store Server Library, and `AppTransaction.shared` is the modern replacement for the app receipt. For UI, prefer Apple's native StoreKit SwiftUI views (`StoreView`, `ProductView`, `SubscriptionStoreView`, and iOS 26's `SubscriptionOfferView`) over hand-rolled paywalls. iOS 26 is shipping; iOS 27 / Xcode 27 (WWDC June 2026) add commitment plans, reworked offer-code redemption, and bundles/suites/multi-user subscriptions — treat these as pre-GA.

## Key facts
- [since iOS 15|high] StoreKit 2 is the current modern API (async/await, Swift). Core flow: load with Product.products(for:), buy with product.purchase(options:), every result wrapped in VerificationResult<Transaction>. Old StoreKit 1 (SKPaymentQueue/SKProduct/SKPaymentTransactionObserver, on-device receipt file) is legacy — do not use for new apps.
- [since iOS 15|high] Entitlements are computed at runtime, not stored. Iterate Transaction.currentEntitlements (AsyncSequence of VerificationResult<Transaction>) for active non-consumables, current auto-renewable subs, non-renewing subs, and unfinished consumables. Check transaction.revocationDate == nil before granting access.
- [since iOS 15|high] Always run a detached Transaction.updates listener at app launch (in a long-lived Task) to catch purchases made outside the app, Ask-to-Buy approvals, renewals, and refunds; call await transaction.finish() after granting entitlement.
- [since iOS 15|high] VerificationResult<T> has two cases: .verified(T) and .unverified(T, VerificationError). StoreKit validates the App Store JWS signature for you on-device; treat .unverified as a failure. This replaces manual receipt validation.
- [since iOS 15|high] Subscription specifics live under Product.SubscriptionInfo: .subscriptionGroupID, .status, RenewalState, RenewalInfo (willAutoRenew, autoRenewPreference, expirationReason, gracePeriodExpirationDate), introductory/promotional offers. Query status via product.subscription?.status or Product.SubscriptionInfo.status(for:).
- [since iOS 17|high] Native SwiftUI StoreKit views: StoreView (multi-product store by IDs), ProductView (single product, inline upsell), SubscriptionStoreView (full paywall for one subscription group with picker/CTA/terms/restore). Prefer these over custom paywalls.
- [since iOS 17; .compactPicker/.pagedPicker since iOS 18|high] SubscriptionStoreView control styling via .subscriptionStoreControlStyle(...): default .automatic plus .buttons, .picker, .prominentPicker; iOS 18 added .compactPicker and .pagedPicker. Marketing content via SubscriptionStoreView(groupID:) { ... } content closures and .subscriptionStoreControlIcon, .storeButton, .subscriptionStorePolicyDestination modifiers.
- [iOS 26 (WWDC25)|high] iOS 26 (WWDC25) added SubscriptionOfferView — a new SwiftUI view to merchandise upgrade/downgrade/crossgrade offers within a subscription group. Init forms: SubscriptionOfferView(productID:), SubscriptionOfferView(groupID:visibleRelationship:) with .upgrade/.downgrade/.crossgrade/.current/.all, or SubscriptionOfferView(subscription:). Options: prefersPromotionalIcon, custom/placeholder icon ViewBuilder, useAppIcon. Pair with .subscriptionOfferViewDetailAction(...).
- [sheets since iOS 15; subscriptionStatusTask since iOS 17|high] SwiftUI lifecycle modifiers: .subscriptionStatusTask(for: groupID) to load/observe subscription status; .manageSubscriptionsSheet(isPresented:) to show Apple's manage-subscriptions UI; .refundRequestSheet(for: transactionID, isPresented:) for refunds; .currentEntitlementTask / .storeProductsTask helpers; .onInAppPurchaseCompletion for StoreKit views. UIKit equivalents: AppStore.showManageSubscriptions(in:) and Transaction.beginRefundRequest(in:).
- [since iOS 16|high] AppTransaction is the modern app-receipt replacement. Read AppTransaction.shared (cached, returns VerificationResult<AppTransaction>); only call AppTransaction.refresh() in response to a suspected discrepancy (like AppStore.sync()). Exposes originalAppVersion, originalPurchaseDate, appTransactionID, deviceVerificationID. Useful for paid-up-front and free-to-paid checks.
- [iOS 18.4 (WWDC25)|high] WWDC25 added new fields: AppTransaction.appTransactionID (globally unique per Apple Account, back-deployed to iOS 15) and AppTransaction.originalPlatform (AppStore.Platform). Transaction gained appTransactionID, offer.offerPeriod, advancedCommerceInfo. RenewalInfo gained appTransactionID, offerPeriod, advancedCommerceInfo, appAccountToken. New: Product.SubscriptionInfo.status(for: transactionID).
- [iOS 18.4|high] Transaction.currentEntitlement(for:) (singular) is deprecated; use Transaction.currentEntitlements(for:) (plural, async sequence supporting multiple entitlements per product).
- [iOS 18.4 (WWDC25), back-deployed to iOS 15|high] WWDC25 added signed purchase options requiring JWS: .introductoryOfferEligibility (set intro-offer eligibility) and .promotionalOffer (sign promo offers). New SwiftUI modifiers .subscriptionPromotionalOffer(offer:isEligible:) and .subscriptionOfferViewDetailAction(...). Sign server-side with the App Store Server Library (Swift/Java/Python/Node) via PromotionOfferV2SignatureCreator.
- [iOS 18.x; win-back offers since iOS 18|high] Offer codes expanded to consumables, non-consumables, and non-renewing subscriptions (redemption back-deployed to iOS 16.3). New Transaction.Offer.PaymentMode.oneTime (iOS 17.2+) alongside .freeTrial, .payAsYouGo, .payUpFront. Offer types: introductory, promotional, offer codes, and win-back offers (iOS 18+).
- [iOS 18.2|high] Purchase methods since iOS 18.2 require a UI context so the system shows the payment sheet/success dialog in the right place: pass a UIViewController (iOS/Catalyst/tvOS/visionOS) or NSWindow (macOS); watchOS needs none. In SwiftUI use the @Environment(\.purchase) PurchaseAction instead.
- [since iOS 14 / Xcode 12; ongoing|high] Local testing uses a .storekit StoreKit configuration file (Xcode) plus the Transaction Manager (Debug > StoreKit) to simulate purchases, refunds, renewals, Ask-to-Buy, and subscription offers without App Store Connect. Production setup is done in App Store Connect (products, subscription groups, offers, offer codes).
- [current (iOS 16+ era)|high] Server-side validation uses the App Store Server API and App Store Server Notifications V2 (signed JWS payloads), with the open-source App Store Server Library (Swift/Java/Python/Node) for verifying/decoding/signing. verifyReceipt and the old shared-secret flow are legacy. Report-style endpoints decode signedTransactionInfo / signedRenewalInfo.
- [2025|high] Advanced Commerce API (announced Jan/Feb 2025) lets apps with large/dynamic catalogs (creator platforms, large content libraries) manage IAP products at runtime outside App Store Connect while still using Apple's commerce system; surfaces via Transaction.advancedCommerceInfo / RenewalInfo.advancedCommerceInfo. Requires Apple approval/eligibility.
- [since iOS 15.4 (entitlement-gated); expanded 2024-2026|high] External purchase: ExternalPurchaseLink (Apple-templated copy) and ExternalPurchaseCustomLink (more flexible, EU) let qualifying apps link out to web purchases under the External Purchase Link Entitlement. Transactions must be reported to Apple via the External Purchase Server API (within ~15 days) for commission calculation.
- [2025-2026 (EU/US, regulatory, may change)|medium] EU/DMA economics: from June 26, 2025 a 5% Core Technology Commission (CTC) applies to externally-communicated/promoted digital sales; Apple announced transitioning from the Core Technology Fee (CTF) to a single CTC-based model for all EU developers by Jan 1, 2026. Alternative distribution (alternative app marketplaces / web distribution) remains EU-only. US now permits external purchase links but the same global build can violate App Store rules (e.g. clause 3.1.1) in Japan, Canada, Australia, UK and most non-EU regions.
- [iOS 26.4+/27, Xcode 27 (pre-GA, may change)|medium] iOS 27 / Xcode 27 (WWDC June 2026) PRE-GA: Commitment Plans — monthly billing with a 12-month commitment. New Product.SubscriptionInfo.pricingTerms, billingPlanType enum (.upFront, .monthly), purchase option .billingPlanType(.monthly), SubscriptionStoreView modifier .preferredSubscriptionPricingTerms { ... }. Transaction/RenewalInfo gain commitmentInfo (billingPeriodNumber, totalBillingPeriods, commitmentExpiresDate, commitmentPrice) and renewalBillingPlanType.
- [Xcode 27 (pre-GA, may change)|medium] iOS 27 / Xcode 27 PRE-GA: reworked in-app offer code redemption — new modifier .offerCodeRedemption(options:isPresented:) { result in ... } that returns a VerificationResult<Transaction> on success and an error on failure (parity with purchase). UIKit equivalent presentOfferCodeRedeemSheet. Testable for all product types in Xcode 27.
- [WWDC26 (pre-GA, program details TBD)|medium] WWDC26 PRE-GA: App Store Bundles (subscribe to multiple apps from different developers at a better price; subs can also be bought individually) and Suites (subscriptions that exist only inside the suite, not standalone). API testable in Xcode 27; full program details later in 2026.
- [WWDC26 (pre-GA, dated targets)|medium] WWDC26 PRE-GA: Multi-user subscriptions powered by StoreKit 2 — two new configuration options for groups/organizations. Volume purchasing via Apple Business Manager / Apple School Manager (enterprise & education) targeted Fall 2026; group purchases (buy seats once, invite others) targeted Winter 2026. Also: Retention Messaging during cancellation, and unified App Review submission grouping IAPs with other review items via the reviewSubmissions App Store Connect API.

## APIs
- `Product` (struct; iOS 15+) — Product.products(for:), .purchase(options:), .displayPrice, .type, .subscription
- `Product.PurchaseResult` (enum; iOS 15+) — .success(VerificationResult<Transaction>), .userCancelled, .pending
- `Product.PurchaseOption` (struct/static; iOS 15+) — .appAccountToken, .quantity, .promotionalOffer, .introductoryOfferEligibility (iOS 18.4), .billingPlanType (iOS 27 pre-GA)
- `VerificationResult` (enum; iOS 15+) — .verified(T) / .unverified(T, VerificationError); generic wrapper for all signed StoreKit values
- `Transaction` (struct; iOS 15+) — .currentEntitlements, .updates, .all, .finish(), .revocationDate, .appAccountToken, .appTransactionID (iOS 18.4), .advancedCommerceInfo (iOS 18.4)
- `Transaction.currentEntitlements` (static async sequence; iOS 15+) — Source of truth for active entitlements on-device
- `Transaction.currentEntitlements(for:)` (static func; iOS 18.4+) — Replaces deprecated currentEntitlement(for:) (singular)
- `Transaction.updates` (static async sequence; iOS 15+) — Long-lived listener for renewals/refunds/out-of-app purchases
- `Transaction.beginRefundRequest(in:)` (func; iOS 15+) — UIKit refund flow; SwiftUI uses .refundRequestSheet
- `Product.SubscriptionInfo` (struct; iOS 15+) — .status, .subscriptionGroupID, .introductoryOffer, .promotionalOffers, .status(for:) (iOS 18.4)
- `Product.SubscriptionInfo.Status` (struct; iOS 15+) — .state (RenewalState), .transaction, .renewalInfo
- `Product.SubscriptionInfo.RenewalState` (struct/enum; iOS 15+) — .subscribed, .expired, .inBillingRetryPeriod, .inGracePeriod, .revoked
- `Product.SubscriptionInfo.RenewalInfo` (struct; iOS 15+) — .willAutoRenew, .autoRenewPreference, .expirationReason, .gracePeriodExpirationDate, .offerPeriod (iOS 18.4)
- `Transaction.Offer.PaymentMode` (struct; iOS 17.2+) — .freeTrial, .payAsYouGo, .payUpFront, .oneTime (iOS 17.2)
- `AppTransaction` (struct; iOS 16+) — .shared, .refresh(), .originalAppVersion, .originalPurchaseDate, .appTransactionID (iOS 18.4), .originalPlatform (iOS 18.4)
- `StoreView` (SwiftUI view; iOS 17+) — Multi-product store by IDs
- `ProductView` (SwiftUI view; iOS 17+) — Single-product inline upsell
- `SubscriptionStoreView` (SwiftUI view; iOS 17+) — Full subscription paywall for one group; init(groupID:) / init(productIDs:)
- `SubscriptionOfferView` (SwiftUI view; iOS 26+) — Merchandise upgrade/downgrade/crossgrade offers; visibleRelationship .upgrade/.downgrade/.crossgrade/.current/.all
- `subscriptionStoreControlStyle(_:)` (view modifier; iOS 17+) — .automatic/.buttons/.picker/.prominentPicker; .compactPicker/.pagedPicker (iOS 18)
- `subscriptionStatusTask(for:priority:action:)` (view modifier; iOS 17+) — Declaratively load/observe subscription group status
- `manageSubscriptionsSheet(isPresented:)` (view modifier; iOS 15+) — Apple manage-subscriptions UI
- `refundRequestSheet(for:isPresented:)` (view modifier; iOS 15+) — Refund request UI; takes transaction ID
- `offerCodeRedemption(isPresented:onCompletion:)` (view modifier; iOS 16+; reworked Xcode 27 (pre-GA) to return VerificationResult) — In-app offer code entry; UIKit presentOfferCodeRedeemSheet
- `PurchaseAction` (struct (@Environment(\.purchase)); iOS 17+) — SwiftUI purchase trigger; satisfies iOS 18.2 UI-context requirement
- `ExternalPurchaseLink` (enum/API; iOS 15.4+ (entitlement-gated)) — Apple-templated external purchase link
- `ExternalPurchaseCustomLink` (API; iOS 17.5+ (EU, entitlement-gated)) — More flexible external link; report via External Purchase Server API
- `Product.SubscriptionInfo.pricingTerms` (property; iOS 27 / Xcode 27 (pre-GA)) — Lists billing plans; billingPlanType .upFront/.monthly (commitment plans)
- `preferredSubscriptionPricingTerms` (view modifier; iOS 27 / Xcode 27 (pre-GA)) — Pick a billing plan for SubscriptionStoreView

## Patterns

### Load products and purchase with verification  — Core purchase flow for any product type.
purchase() can return .userCancelled or .pending (Ask-to-Buy / SCA). Always unwrap VerificationResult and reject .unverified. Call finish() only after you've granted the entitlement.
```swift
@MainActor @Observable final class Store {
    var products: [Product] = []
    var purchasedIDs: Set<String> = []

    func load() async throws {
        products = try await Product.products(for: ["pro.monthly", "pro.yearly"])
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateEntitlements()
            await transaction.finish()
        case .userCancelled, .pending: break
        @unknown default: break
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }
}
```

### Launch-time transaction listener + entitlement refresh  — Run once at app start to catch renewals, refunds, family-shared and out-of-app purchases.
Start the listener before any await that could miss an update. Never trust local state alone for revoked/refunded purchases — currentEntitlements is the source of truth on-device.
```swift
func observeTransactions() -> Task<Void, Never> {
    Task.detached { [weak self] in
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await self?.updateEntitlements()
            await transaction.finish()
        }
    }
}

func updateEntitlements() async {
    var owned: Set<String> = []
    for await result in Transaction.currentEntitlements {
        guard case .verified(let t) = result, t.revocationDate == nil else { continue }
        owned.insert(t.productID)
    }
    purchasedIDs = owned
}
```

### Native subscription paywall with SubscriptionStoreView  — Standard subscription paywall for a single subscription group — preferred over a custom paywall.
SubscriptionStoreView renders Apple-managed pricing, intro offers, terms, and restore. Use .subscriptionStoreControlStyle to switch picker/buttons; iOS 18 adds .compactPicker/.pagedPicker.
```swift
SubscriptionStoreView(groupID: "21435678") {
    VStack { Text("Unlock Pro").font(.largeTitle.bold()) }
        .containerBackground(.blue.gradient, for: .subscriptionStore)
}
.subscriptionStoreControlStyle(.prominentPicker)
.storeButton(.visible, for: .restorePurchases)
.subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
.onInAppPurchaseCompletion { product, result in
    // refresh entitlements
}
```

### Observe subscription status declaratively  — Gate features on current subscription state across the app.
subscriptionStatusTask (iOS 17+) reloads automatically when status changes. Translate StoreKit RenewalState into your own app model and vend it via the environment.
```swift
ContentView()
    .subscriptionStatusTask(for: "21435678") { taskState in
        if let statuses = taskState.value {
            let active = statuses.contains { status in
                if case .verified(let info) = status.renewalInfo {
                    return status.state == .subscribed || status.state == .inGracePeriod
                }
                return false
            }
            model.isSubscribed = active
        }
    }
```

### Manage-subscriptions and refund sheets  — Let users manage or request a refund from inside the app (App Review often expects this).
UIKit equivalents: AppStore.showManageSubscriptions(in: scene) and Transaction.beginRefundRequest(in: scene).
```swift
.manageSubscriptionsSheet(isPresented: $showManage)
.refundRequestSheet(for: transactionID, isPresented: $showRefund) { result in
    // .success(.success) / .success(.userCancelled) / .failure
}
```

### AppTransaction for paid-app / original-version checks  — Determine whether a user bought the paid app or which version they first installed (e.g. grandfathering).
Prefer AppTransaction.shared (cached). Only call AppTransaction.refresh() in response to a user action when you suspect tampering — it can prompt for App Store auth.
```swift
let verification = try await AppTransaction.shared
if case .verified(let appTransaction) = verification {
    let firstVersion = appTransaction.originalAppVersion
    let installedDate = appTransaction.originalPurchaseDate
}
```

## Pitfalls
- Trusting local/cached purchase state instead of Transaction.currentEntitlements — you'll miss refunds, revocations, and family-sharing changes. Recompute from currentEntitlements and honor revocationDate.
- Forgetting to call transaction.finish() — unfinished transactions (especially consumables) replay via Transaction.updates forever and can block future purchases.
- Not starting the Transaction.updates listener at launch (before awaits) — purchases approved out-of-app (Ask-to-Buy) or via the App Store are missed.
- Treating .unverified as success — always reject it; it indicates a failed JWS signature check.
- Assuming purchase() always succeeds — handle .userCancelled and .pending (Ask-to-Buy / Strong Customer Authentication) explicitly.
- Since iOS 18.2, purchase methods require a UI context (UIViewController/NSWindow); calling the contextless overload can fail to present correctly — in SwiftUI use the @Environment(\.purchase) PurchaseAction or the StoreKit views.
- Hand-rolling paywalls when SubscriptionStoreView/StoreView would give correct localized pricing, intro-offer eligibility, terms, and restore for free — and are what App Review expects.
- Shipping the same external-purchase-link build globally: it's permitted in the EU and now the US, but still violates App Store rules (e.g. 3.1.1) in Japan, Canada, Australia, the UK and most regions — gate by storefront.
- Reusing StoreKit 1 receipt-validation/verifyReceipt+shared-secret server logic — migrate to the App Store Server API + Notifications V2 with the App Store Server Library.
- Calling AppTransaction.refresh() or AppStore.sync() on a timer/at launch — both can prompt App Store auth; only call them in response to a user action when a discrepancy is suspected.
- Not providing a Restore Purchases path (Transaction.currentEntitlements + AppStore.sync() on demand) — required for non-consumables/subscriptions and checked by App Review.
- Hardcoding all product IDs at build time when a large/dynamic catalog needs the Advanced Commerce API (which is eligibility-gated and not a drop-in).

## iOS 26 changes
- SubscriptionOfferView added for merchandising upgrade/downgrade/crossgrade offers within a subscription group (visibleRelationship: .upgrade/.downgrade/.crossgrade/.current/.all).
- New fields (iOS 18.4): AppTransaction.appTransactionID & .originalPlatform; Transaction.appTransactionID, .offer.offerPeriod, .advancedCommerceInfo; RenewalInfo.appTransactionID, .offerPeriod, .advancedCommerceInfo, .appAccountToken.
- Transaction.currentEntitlement(for:) deprecated; new Transaction.currentEntitlements(for:) and Product.SubscriptionInfo.status(for: transactionID).
- Signed purchase options .introductoryOfferEligibility and .promotionalOffer (JWS), plus modifiers .subscriptionPromotionalOffer(offer:isEligible:) and .subscriptionOfferViewDetailAction(...).
- Offer codes expanded to consumables, non-consumables, and non-renewing subscriptions (redemption back-deployed to iOS 16.3); new Transaction.Offer.PaymentMode.oneTime (iOS 17.2+).
- App Store Server Library adds PromotionOfferV2SignatureCreator for signing promo offers in JWS (Swift/Java/Python/Node).

## iOS 27 preview (pre-GA)
- Commitment Plans: monthly billing with a 12-month commitment via Product.SubscriptionInfo.pricingTerms, billingPlanType (.upFront/.monthly), purchase option .billingPlanType(.monthly), modifier .preferredSubscriptionPricingTerms; Transaction/RenewalInfo gain commitmentInfo (billingPeriodNumber, totalBillingPeriods, commitmentExpiresDate, commitmentPrice) and renewalBillingPlanType. | Pre-GA (Xcode 27 beta, iOS 26.4+/27). Exact field names from secondary source corroborating WWDC26; verify against final Apple docs.
- Reworked in-app offer code redemption: .offerCodeRedemption(options:isPresented:) returns VerificationResult<Transaction> on success (parity with purchase); UIKit presentOfferCodeRedeemSheet. | Pre-GA; API shape may change before release.
- App Store Bundles (multi-developer subscription bundles, also individually purchasable) and Suites (subscriptions that exist only within the suite). API testable in Xcode 27. | Pre-GA; full program details and exact StoreKit type names announced later in 2026.
- Multi-user subscriptions (StoreKit 2): two new configuration options for groups/organizations — volume purchasing via Apple Business/School Manager (Fall 2026) and group seat purchases with invites (Winter 2026). Plus Retention Messaging during cancellation and unified App Review submission (reviewSubmissions API). | Pre-GA / phased rollout with dated targets that may slip; exact StoreKit configuration option names not yet in public docs.

## Deprecations
- StoreKit 1 (SKPaymentQueue, SKProduct, SKPayment, SKPaymentTransactionObserver, SKProductsRequest) is legacy — use StoreKit 2 for all new code.
- On-device receipt validation against the bundle receipt file and the verifyReceipt endpoint (+ App Store shared secret) is legacy — use VerificationResult on-device and the App Store Server API / Notifications V2 server-side.
- App Store Server Notifications V1 superseded by V2 (signed JWS payloads).
- Transaction.currentEntitlement(for:) (singular) deprecated in iOS 18.4 — use Transaction.currentEntitlements(for:) (plural).
- Manual app-receipt parsing replaced by AppTransaction (iOS 16+).
- Per-resource App Store Connect IAP/subscription review-submission endpoints being deprecated in favor of unified reviewSubmissions/reviewSubmissionItems (WWDC26, pre-GA).

## Libraries
- App Store Server Library (Swift): Verify/decode signed JWS transactions and renewal info from App Store Server API & Notifications V2; sign promotional offers (PromotionOfferV2SignatureCreator). Also Java/Python/Node. (https://github.com/apple/app-store-server-library-swift)
- RevenueCat (purchases-ios): Optional third-party layer over StoreKit 2 for cross-platform entitlements, server receipt validation, and paywalls when you don't want to run subscription infra yourself. (https://github.com/RevenueCat/purchases-ios)

## Uncertainties
- Exact iOS 27 / Xcode 27 commitment-plan symbol names (pricingTerms, billingPlanType, commitmentInfo, .preferredSubscriptionPricingTerms, .billingPlanType(.monthly)) come from a corroborating secondary source (BleepingSwift) reflecting WWDC26 — confirm spelling/signatures against final Apple documentation when published.
- The precise StoreKit configuration option names for WWDC26 multi-user subscriptions and the exact Bundles/Suites StoreKit types are not yet in public Apple docs (program details promised later in 2026).
- Whether commitment plans are gated to iOS 26.4/26.5 vs a clean iOS 27 minimum is reported inconsistently across secondary sources; treat the version floor as approximate until Apple docs confirm.
- EU/DMA fee structure (CTF→CTC transition, 5% CTC, single business model by Jan 1, 2026) is regulatory and changed repeatedly through 2024-2026 — re-verify current terms before relying on specific percentages or dates.
- Could not load the live Apple documentation body for Transaction.currentEntitlements (page returned title only); signatures stated are from WWDC sessions and corroborating sources rather than a fresh doc fetch.

## Sources
- What's new in StoreKit and In-App Purchase — WWDC25 (session 241): https://developer.apple.com/videos/play/wwdc2025/241/
- What's new in Apple In-App Purchase — WWDC26 (session 210): https://developer.apple.com/videos/play/wwdc2026/210/
- Apple expands App Store capabilities (Apple Newsroom, June 2026): https://www.apple.com/newsroom/2026/06/apple-expands-app-store-capabilities-to-help-developers-grow-and-reach-new-users/
- What's New in StoreKit for Xcode 27: Commitment Plans, Offer Codes (BleepingSwift): https://bleepingswift.com/blog/whats-new-storekit-ios-27
- Transaction.currentEntitlements — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/transaction/currententitlements
- Transaction — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/transaction
- SubscriptionStoreView — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/subscriptionstoreview
- subscriptionStatusTask — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/subscriptionstoreview/4211637-subscriptionstatustask
- Meet StoreKit 2 — WWDC21 (session 10114): https://developer.apple.com/videos/play/wwdc2021/10114/
- Mastering StoreKit 2 — Swift with Majid: https://swiftwithmajid.com/2023/08/01/mastering-storekit2/
- StoreKit views guide: build a paywall with SwiftUI — RevenueCat: https://www.revenuecat.com/blog/engineering/storekit-views-guide-paywall-swift-ui/
- External Purchase — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/external-purchase
- Update on apps distributed in the EU (DMA) — Apple Developer Support: https://developer.apple.com/support/dma-and-apps-in-the-eu/
- Advanced Commerce API — Apple In-App Purchase: https://developer.apple.com/in-app-purchase/advanced-commerce-api/
- App Store Server Library (Swift) — GitHub: https://github.com/apple/app-store-server-library-swift
- StoreKit2: Testing AppTransaction Receipt Verification — Apple Developer Forums: https://developer.apple.com/forums/thread/791237
