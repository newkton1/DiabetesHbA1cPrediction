//
//  SubscriptionManager.swift
//  DiabetesHbA1cPrediction
//
//  StoreKit 2 manager for the Diabetes Feast annual subscription.
//  Product ID: com.diabetesfeastjp.DiabetesFeast.annual
//
//  Responsibilities:
//    - Fetch the subscription product from App Store Connect
//    - Process purchases (initiates StoreKit transaction)
//    - Verify and expose current subscription status
//    - Restore purchases
//    - Listen for external transaction updates (renewals, cancellations)
//

import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Product ID

    static let annualProductID = "com.diabetesfeastjp.DiabetesFeast.annual"

    // MARK: - Published State

    /// The fetched StoreKit product (nil until loaded)
    @Published var product: Product?

    /// Whether the user currently has an active subscription
    @Published var isSubscribed: Bool = false

    /// Whether a purchase or restore is in progress
    @Published var isPurchasing: Bool = false

    /// Last error message to display in the UI
    @Published var errorMessage: String?

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init

    private init() {
        // Start listening for StoreKit transaction updates
        // (renewals, refunds, billing retries, etc.)
        transactionListener = listenForTransactions()

        Task {
            await fetchProduct()
            await refreshSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Fetch Product

    /// Loads the subscription product from App Store Connect.
    func fetchProduct() async {
        do {
            let products = try await Product.products(for: [Self.annualProductID])
            product = products.first
        } catch {
            errorMessage = "Could not load subscription details. Please check your connection."
        }
    }

    // MARK: - Purchase

    /// Initiates the StoreKit purchase flow for the annual subscription.
    /// Returns true if the purchase succeeded.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = "Subscription product not available. Please try again."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
                return true

            case .userCancelled:
                return false

            case .pending:
                // Transaction is awaiting approval (e.g. Ask to Buy)
                errorMessage = "Your purchase is pending approval."
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restores any previously completed purchases.
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Subscription Status

    /// Checks all current entitlements and updates isSubscribed.
    func refreshSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.annualProductID,
               transaction.revocationDate == nil {
                hasActiveSubscription = true
                break
            }
        }

        isSubscribed = hasActiveSubscription
    }

    // MARK: - Transaction Listener

    /// Listens for StoreKit transaction updates in the background.
    /// Handles renewals, cancellations, and billing retries automatically.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.refreshSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    // Verification failed — do not grant access
                }
            }
        }
    }

    // MARK: - Verification Helper

    /// Unwraps a VerificationResult, throwing if verification failed.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed. Please contact support."
        }
    }
}
