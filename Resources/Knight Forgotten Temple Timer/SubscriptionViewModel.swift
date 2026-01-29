import SwiftUI
import StoreKit
import Combine

/// ViewModel to manage subscription status and purchasing.
@MainActor
final class SubscriptionViewModel: ObservableObject {
    // MARK: - Published state
    @Published var isSubscribed: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil

    // MARK: - Product IDs
    // Replace with your actual App Store Connect product IDs if you add more tiers
    static let monthlyProductID = "promonth.forgottentempleko"
    static let productIDs: Set<String> = [monthlyProductID]

    // MARK: - Init
    init() {
      Task {
            await loadProducts()
        }
        // Begin observing transaction updates as soon as the VM is created
        observeTransactions()
    }

    // MARK: - Product loading
    /// Load products from App Store.
    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            products = try await Product.products(for: Array(Self.productIDs))
            if products.isEmpty {
                purchaseError = "Ürünler yüklenemedi"
            }
        } catch {
            purchaseError = "Product load error: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase
    /// Purchase a given product.
    func purchase(product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await applyEntitlements(from: transaction)
                    await transaction.finish()
                } catch {
                    purchaseError = "Doğrulama hatası: \(error.localizedDescription)"
                }
            case .userCancelled:
                // Kullanıcı iptal etti, hata göstermeyelim
                break
            case .pending:
                // Ask to Buy vb. durumlar
                purchaseError = "Satın alma beklemede. Lütfen onayı tamamlayın."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase error: \(error.localizedDescription)"
        }
        // Satın alma sonrası entitlement'ları tazele
        await refreshEntitlements()
    }

    // MARK: - Entitlements
    /// Refresh subscription entitlements.
    func refreshEntitlements() async {
        var active = false
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if Self.productIDs.contains(transaction.productID) {
                    active = true
                    break
                }
            } catch {
                // doğrulanamayan işlem, yok say
            }
        }
        isSubscribed = active
    }

    /// Restore past transactions.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore error: \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    // MARK: - Transaction observation
    private func observeTransactions() {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(update)
                    await self.applyEntitlements(from: transaction)
                    await transaction.finish()
                } catch {
                    await MainActor.run { [weak self] in
                        self?.purchaseError = "Transaction update error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func applyEntitlements(from transaction: StoreKit.Transaction) async {
        if Self.productIDs.contains(transaction.productID) {
            isSubscribed = true
        }
    }

    /// Verify a transaction or verification result from StoreKit.
    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // Convenience computed property to get current product.
    var currentProduct: Product? {
        products.first { Self.productIDs.contains($0.id) }
    }
}

