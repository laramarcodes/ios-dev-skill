# In-app purchases & subscriptions (StoreKit 2)

How to sell consumables, non-consumables, and auto-renewable subscriptions in a native SwiftUI app using the modern **In-App Purchase (Swift)** API — Apple's docs call it the **In-App Purchase (Swift)** API; "StoreKit 2" is Apple's marketing/WWDC term for it (since iOS 15). It is async/await, Swift-native, and validates App Store signatures for you; entitlement state is *computed at runtime* from transactions, never parsed from a receipt file. Don't write StoreKit 1 (`SKPaymentQueue`/`SKProduct`) for new code. (Shipping baseline as of June 2026: iOS 26, Xcode 26.5, Swift 6.3.2.)

**Contents**
- [Mental model](#mental-model)
- [The core purchase flow](#the-core-purchase-flow)
- [Entitlements & the launch-time listener](#entitlements--the-launch-time-listener)
- [Subscriptions](#subscriptions)
- [Native StoreKit SwiftUI views](#native-storekit-swiftui-views)
- [Manage, refund, restore, redeem](#manage-refund-restore-redeem)
- [AppTransaction (the receipt replacement)](#apptransaction-the-receipt-replacement)
- [Local testing & App Store Connect](#local-testing--app-store-connect)
- [Server-side validation](#server-side-validation)
- [Policy: external purchases, EU/DMA, RevenueCat](#policy-external-purchases-eudma-revenuecat)
- [iOS 27 / Xcode 27 preview (pre-GA)](#ios-27--xcode-27-preview-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Mental model

Four moving parts, all in `import StoreKit`:

| Concept | Type | Role |
|---|---|---|
| Catalog | `Product` | Load metadata + price by ID; call `.purchase()` |
| Proof of a sale | `Transaction` | App Store JWS-signed record of one purchase |
| Signature wrapper | `VerificationResult<T>` | Every signed value arrives as `.verified` / `.unverified` |
| Live entitlements | `Transaction.currentEntitlements` | The on-device source of truth — recompute, don't cache |

The golden rule: **you never store "user is Pro" as a fact you trust.** You recompute it from `Transaction.currentEntitlements` (an async sequence) whenever it might have changed, and you keep a long-lived `Transaction.updates` listener running to catch changes that happen outside your purchase flow (renewals, refunds, Ask-to-Buy approvals, family sharing). This is the whole reason StoreKit 2 has no "validate receipt" step on device — the signature check *is* the validation.

## The core purchase flow

Load products with `Product.products(for:)`, buy with `product.purchase()`. The result is a `Product.PurchaseResult` with three cases you must all handle. `.pending` happens with Ask-to-Buy (parental approval) and Strong Customer Authentication — the purchase isn't done, it'll arrive later via the updates listener.

```swift
@MainActor @Observable final class Store {
    var products: [Product] = []
    var purchasedIDs: Set<String> = []

    func load() async throws {
        products = try await Product.products(for: ["pro.monthly", "pro.yearly"])
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()           // iOS 15+
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateEntitlements()                       // grant access FIRST
            await transaction.finish()                       // then finish
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error          // never grant on .unverified
        }
    }
}
```

**iOS 18.2+ UI context:** `purchase()` now wants to know *where* to present the payment sheet. In SwiftUI, trigger purchases through the `@Environment(\.purchase)` `PurchaseAction` (iOS 17+) or the StoreKit views below — both satisfy this automatically. In UIKit you pass a `UIViewController`. Calling a context-less overload can fail to present correctly.

```swift
@Environment(\.purchase) private var purchase           // PurchaseAction, iOS 17+
// ...
let result = try await purchase(product)
```

Useful `Product.PurchaseOption`s passed to `purchase(options:)`: `.appAccountToken(_:)` to tie a sale to your own user ID, `.quantity(_:)` for consumables, and the iOS 18.4 signed options `.introductoryOfferEligibility(_:)` / `.promotionalOffer(...)` (require a JWS signature — sign server-side with the App Store Server Library's `PromotionOfferV2SignatureCreator`).

## Entitlements & the launch-time listener

Run the `Transaction.updates` listener for the entire app lifetime, started **at launch before any other await**, or you'll miss out-of-app purchases and renewals. Recompute entitlements from `currentEntitlements`, honoring `revocationDate` (refunds/charge-backs set it).

```swift
func observeTransactions() -> Task<Void, Never> {
    Task.detached { [weak self] in
        for await update in Transaction.updates {           // iOS 15+, long-lived
            guard case .verified(let transaction) = update else { continue }
            await self?.updateEntitlements()
            await transaction.finish()
        }
    }
}

func updateEntitlements() async {
    var owned: Set<String> = []
    for await result in Transaction.currentEntitlements {    // iOS 15+
        guard case .verified(let t) = result, t.revocationDate == nil else { continue }
        owned.insert(t.productID)
    }
    purchasedIDs = owned
}
```

Keep the returned `Task` alive (store it on your `App`/model). Note `Transaction.currentEntitlement(for:)` (singular) is **deprecated in iOS 18.4** — use `Transaction.currentEntitlements(for:)` (plural async sequence), which supports multiple entitlements per product.

## Subscriptions

Subscription-specific data hangs off `product.subscription` (`Product.SubscriptionInfo`, iOS 15+): `subscriptionGroupID`, `introductoryOffer`, `promotionalOffers`, and `status`. Read status declaratively in SwiftUI with `.subscriptionStatusTask(for:)` (iOS 17+) — it reloads automatically when the subscription changes.

```swift
ContentView()
    .subscriptionStatusTask(for: "21435678") { taskState in   // groupID
        guard let statuses = taskState.value else { return }
        model.isSubscribed = statuses.contains { status in
            status.state == .subscribed || status.state == .inGracePeriod
        }
    }
```

`RenewalState` values you care about: `.subscribed`, `.inGracePeriod`, `.inBillingRetryPeriod` (still grant access — payment is being retried), `.expired`, `.revoked`. `RenewalInfo` tells you `willAutoRenew`, `autoRenewPreference` (a pending plan change), `expirationReason`, and `gracePeriodExpirationDate`. To grandfather users or branch on a specific subscription, use `Product.SubscriptionInfo.status(for: transactionID)` (iOS 18.4+).

Offer types: **introductory** (first-time), **promotional** (signed, for existing/lapsed users), **offer codes** (redeemable, now usable for consumables/non-consumables/non-renewing subs; redemption back-deployed to iOS 16.3), and **win-back offers** (iOS 18+, target lapsed subscribers via the App Store). Payment modes live on `Transaction.Offer.PaymentMode`: `.freeTrial`, `.payAsYouGo`, `.payUpFront`, `.oneTime` (iOS 17.2+).

## Native StoreKit SwiftUI views

Prefer Apple's views over a hand-rolled paywall — you get correct localized pricing, intro-offer eligibility, terms, and Restore for free, and App Review expects them.

| View | Since | Use |
|---|---|---|
| `ProductView` | iOS 17 | Single product, inline upsell |
| `StoreView` | iOS 17 | Multi-product store from a list of IDs |
| `SubscriptionStoreView` | iOS 17 | Full paywall for one subscription group |
| `SubscriptionOfferView` | iOS 26 | Merchandise upgrade/downgrade/crossgrade within a group |

```swift
SubscriptionStoreView(groupID: "21435678") {
    VStack { Text("Unlock Pro").font(.largeTitle.bold()) }
        .containerBackground(.blue.gradient, for: .subscriptionStore)
}
.subscriptionStoreControlStyle(.prominentPicker)        // .compactPicker/.pagedPicker iOS 18+
.storeButton(.visible, for: .restorePurchases)
.subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
.onInAppPurchaseCompletion { product, result in
    await store.updateEntitlements()
}
```

`subscriptionStoreControlStyle` options: `.automatic`, `.buttons`, `.picker`, `.prominentPicker`; iOS 18 added `.compactPicker` and `.pagedPicker`. **iOS 26** `SubscriptionOfferView` merchandises cross-tier offers — `SubscriptionOfferView(groupID:visibleRelationship:)` with `.upgrade` / `.downgrade` / `.crossgrade` / `.current` / `.all`, paired with `.subscriptionOfferViewDetailAction(...)`. See `swiftui-views.md` for layout/styling and `liquid-glass.md` for theming these surfaces on iOS 26.

## Manage, refund, restore, redeem

App Review expects in-app paths for managing and refunding subscriptions, plus an explicit **Restore Purchases** action for non-consumables and subscriptions.

```swift
.manageSubscriptionsSheet(isPresented: $showManage)                 // iOS 15+
.refundRequestSheet(for: transactionID, isPresented: $showRefund) { result in
    // .success(.success) / .success(.userCancelled) / .failure
}
.offerCodeRedemptionSheet(isPresented: $showRedeem)                 // iOS 16+
```

UIKit equivalents: `AppStore.showManageSubscriptions(in: scene)`, `Transaction.beginRefundRequest(in: scene)`, `presentOfferCodeRedeemSheet`. **Restore** = call `await updateEntitlements()` (recompute from `currentEntitlements`); only call `AppStore.sync()` from an explicit user tap, since it can prompt for App Store authentication.

## AppTransaction (the receipt replacement)

`AppTransaction` (iOS 16+) replaces manual app-receipt parsing — use it for "did this user buy the paid app?" or "which version did they first install?" (grandfathering). Read the **cached** `AppTransaction.shared`; only call `AppTransaction.refresh()` from a user action when you suspect tampering (it can prompt for auth).

```swift
if case .verified(let appTransaction) = try await AppTransaction.shared {
    let firstVersion = appTransaction.originalAppVersion
    let installed    = appTransaction.originalPurchaseDate
    let acctID       = appTransaction.appTransactionID      // iOS 18.4, back-deployed to iOS 15
}
```

iOS 18.4 added `appTransactionID` (globally unique per Apple Account) and `originalPlatform` to `AppTransaction`, and `appTransactionID` / `offer.offerPeriod` to `Transaction`.

## Local testing & App Store Connect

Add a **`.storekit` configuration file** (Xcode ▸ File ▸ New ▸ StoreKit Configuration File) and select it in the scheme's Run ▸ Options. It lets you define products and test purchases, refunds, renewals, Ask-to-Buy, and offers with **no App Store Connect round-trip**. Drive scenarios from the **Transaction Manager** (Xcode ▸ Debug ▸ StoreKit ▸ Manage Transactions). Subscription renewals are time-compressed (a month can pass in seconds). Production products, subscription groups, offers, and offer codes are configured in App Store Connect. See `testing-and-debugging.md` for wiring StoreKit tests with Swift Testing.

## Server-side validation

For server-authoritative entitlements (recommended for anything valuable), don't trust the client. Use the **App Store Server API** (query transactions/subscription status) and **App Store Server Notifications V2** (Apple pushes signed JWS events: renewals, refunds, billing issues). Decode and verify the signed `signedTransactionInfo` / `signedRenewalInfo` payloads with the open-source **App Store Server Library** (Swift/Java/Python/Node). The legacy `verifyReceipt` endpoint + shared secret and Notifications V1 are deprecated — do not build new on them.

## Policy: external purchases, EU/DMA, RevenueCat

These are *entitlements and App Store policy*, not StoreKit API changes — they don't alter the code above.

- **External purchase links** — `ExternalPurchaseLink` (Apple-templated copy; US + others) and `ExternalPurchaseCustomLink` (more flexible, EU) let qualifying apps link out to web checkout under the External Purchase Link Entitlement (`com.apple.developer.storekit.external-purchase-link`). You generally must report those sales to Apple via the **External Purchase Server API** (~15 days) for commission. **US status is legally in flux:** the Dec 11, 2025 Ninth Circuit ruling upheld the contempt findings but vacated the blanket commission ban (Apple may charge only a "reasonable" commission tied to genuine coordination costs); Apple petitioned the Supreme Court in 2026 — treat as policy-in-flux, not stable. **Gate by storefront:** the same global build that's allowed in the EU/US still violates App Store rules (e.g. clause 3.1.1) in Japan, Canada, Australia, the UK, and most regions.
- **EU/DMA** — alternative app marketplaces and web distribution use **MarketplaceKit** and are EU-only. The fee model is regulatory and has shifted repeatedly: a **5% Core Technology Commission (CTC)** applies to externally-promoted digital sales (from June 26, 2025), and Apple announced moving all EU developers from the per-install Core Technology Fee (CTF, €0.50/first annual install) to a single CTC model by Jan 1, 2026. **Re-verify current terms** before quoting percentages — this changes.
- **RevenueCat** (`purchases-ios`) — a popular third-party layer over StoreKit 2: cross-platform entitlements, server-side validation, hosted paywalls, and analytics, so you don't run subscription infrastructure yourself. Reasonable default if you don't want to own a server.

## iOS 27 / Xcode 27 preview (pre-GA)

WWDC 2026, ships fall 2026 — testable in Xcode 27 beta, **API names may change; verify against final Apple docs before relying on them.**

- **Commitment Plans** — monthly billing with a 12-month commitment via `Product.SubscriptionInfo.pricingTerms`, a `billingPlanType` enum (`.upFront` / `.monthly`), purchase option `.billingPlanType(.monthly)`, and `SubscriptionStoreView` modifier `.preferredSubscriptionPricingTerms { ... }`. `Transaction`/`RenewalInfo` gain `commitmentInfo` (`billingPeriodNumber`, `totalBillingPeriods`, `commitmentExpiresDate`, `commitmentPrice`).
- **Reworked offer-code redemption** — `.offerCodeRedemption(options:isPresented:) { result in ... }` returns a `VerificationResult<Transaction>` on success (parity with `purchase()`), testable for all product types.
- **App Store Bundles & Suites** — subscribe to multiple apps (across developers) at a better price; Suites are subscriptions that exist only within the suite. Program details later in 2026.
- **Multi-user subscriptions** (StoreKit 2) — volume purchasing via Apple Business/School Manager (targeted Fall 2026) and group seat purchases with invites (Winter 2026), plus retention messaging during cancellation. Exact config option names not yet public.

## Pitfalls

- **Trusting cached "is Pro" state** instead of `Transaction.currentEntitlements` — you'll miss refunds, revocations, and family-sharing changes. Recompute and honor `revocationDate`.
- **Forgetting `transaction.finish()`** — unfinished transactions (especially consumables) replay through `Transaction.updates` forever and can block future purchases. Finish *after* granting access.
- **Not starting `Transaction.updates` at launch** (before other awaits) — Ask-to-Buy approvals and App Store purchases made outside your flow are silently missed.
- **Treating `.unverified` as success** — always reject it; it means the JWS signature check failed.
- **Assuming `purchase()` succeeds** — handle `.userCancelled` and `.pending` (Ask-to-Buy / SCA) explicitly; `.pending` resolves later via the listener.
- **Context-less purchase on iOS 18.2+** — pass a UI context (use `@Environment(\.purchase)` or a StoreKit view in SwiftUI) or the payment sheet may not present.
- **Hand-rolling a paywall** when `SubscriptionStoreView`/`StoreView` give correct localized pricing, intro-offer eligibility, terms, and Restore for free.
- **Shipping one external-purchase-link build globally** — allowed in EU/US, but rule-violating in Japan, Canada, Australia, the UK, and most regions. Gate by storefront.
- **No Restore Purchases path** — required for non-consumables/subscriptions and checked by App Review.
- **`AppStore.sync()` / `AppTransaction.refresh()` on a timer or at launch** — both can prompt App Store auth; only call from an explicit user action when a discrepancy is suspected.
- **Reusing `verifyReceipt` + shared-secret server logic** — migrate to the App Store Server API + Notifications V2 with the App Store Server Library.

## Primary sources

- What's new in StoreKit and In-App Purchase — WWDC25 session 241: https://developer.apple.com/videos/play/wwdc2025/241/
- What's new in Apple In-App Purchase — WWDC26 session 210: https://developer.apple.com/videos/play/wwdc2026/210/
- `Transaction` — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/transaction
- `SubscriptionStoreView` — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/subscriptionstoreview
- External Purchase — Apple Developer Documentation: https://developer.apple.com/documentation/storekit/external-purchase
- App Store Server Library (Swift) — GitHub: https://github.com/apple/app-store-server-library-swift
- Update on apps distributed in the EU (DMA) — Apple Developer Support: https://developer.apple.com/support/dma-and-apps-in-the-eu/
- RevenueCat `purchases-ios` — GitHub: https://github.com/RevenueCat/purchases-ios
