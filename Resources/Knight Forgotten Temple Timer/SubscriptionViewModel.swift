import SwiftUI
import StoreKit
import Combine

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var isSubscribed: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil

    static let monthlyProductID = "promonth.forgottentempleko"
    static let productIDs: Set<String> = [monthlyProductID]

    init() {
        Task { await loadProducts() }
        observeTransactions()
    }

    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            products = try await Product.products(for: Array(Self.productIDs))
            if products.isEmpty {
                purchaseError = "Ürün bilgileri yüklenemedi. Lütfen tekrar deneyin."
            }
        } catch {
            print("Product load error:", error.localizedDescription)
            purchaseError = "Ürün bilgileri yüklenemedi. Lütfen tekrar deneyin."
        }
        isLoading = false
    }

    func purchase(product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                do {
                    let transaction = try Self.checkVerified(verification)
                    await applyEntitlements(from: transaction)
                    await transaction.finish()
                } catch {
                    print("Verification error:", error.localizedDescription)
                    purchaseError = "Satın alma doğrulanamadı. Lütfen tekrar deneyin."
                }

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Satın alma beklemede. Lütfen işlemi tamamlayın."

            @unknown default:
                purchaseError = "Satın alma tamamlanamadı. Lütfen tekrar deneyin."
            }
        } catch {
            print("Purchase error:", error.localizedDescription)
            purchaseError = "Satın alma tamamlanamadı. Lütfen tekrar deneyin."
        }

        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if Self.productIDs.contains(transaction.productID) {
                    active = true
                    break
                }
            } catch { }
        }
        isSubscribed = active
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            print("Restore error:", error.localizedDescription)
            purchaseError = "Geri yükleme başarısız oldu. Lütfen tekrar deneyin."
        }
        await refreshEntitlements()
    }

    private func observeTransactions() {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in StoreKit.Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(update)
                    await self.applyEntitlements(from: transaction)
                    await self.refreshEntitlements()
                    await transaction.finish()
                } catch {
                    print("Transaction update error:", error.localizedDescription)
                    await MainActor.run { [weak self] in
                        self?.purchaseError = "Satın alma doğrulanamadı. Lütfen tekrar deneyin."
                    }
                }
            }
        }
    }

    private func applyEntitlements(from transaction: StoreKit.Transaction) async {
        if Self.productIDs.contains(transaction.productID) {
            isSubscribed = true
        }
    }

    // ✅ MainActor'dan bağımsız: detached içinden çağrılabilir
    private nonisolated static func checkVerified<T>(
        _ result: StoreKit.VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    var currentProduct: Product? {
        products.first { Self.productIDs.contains($0.id) }
    }
}
