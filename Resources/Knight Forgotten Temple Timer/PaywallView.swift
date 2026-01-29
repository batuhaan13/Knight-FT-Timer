import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subVM: SubscriptionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showPurchaseToast: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.2).ignoresSafeArea()
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)
                    Spacer()
                }
                Spacer()
            }
            
            VStack(spacing: 16) {
                Text("PREMIUM👑")
                    .font(.largeTitle.bold())
                
                Text("7 gün ücretsiz dene. Deneme süresi bitince aylık 99,99₺ ile devam eder. İstediğin zaman iptal edebilirsin.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                
                if subVM.isLoading {
                    ProgressView("Ürün yükleniyor…")
                        .tint(.white)
                } else {
                    if let product = subVM.currentProduct {
                        Button("\(product.displayPrice) ile devam et") {
                            Task { await subVM.purchase(product: product) }
                        }
                        .font(.system(.title3, design: .rounded).bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.pink.opacity(0.8)]), startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    } else {
                        Button("99,99 ₺'ye bir aylık satın al ve kusursuz komut ile kazan!🚀") {
                            Task { await subVM.loadProducts() }
                        }
                        .font(.system(.title3, design: .rounded).bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.pink.opacity(0.8)]), startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                }
                
                Button("Satın alımları geri yükle") {
                    Task { await subVM.restore() }
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.white.opacity(0.7))
                
                if let error = subVM.purchaseError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Text("Fiyat bölgenize göre değişiklik gösterebilir. Abonelik otomatik yenilenir. Aboneliği iPhone Ayarları > Apple Kimliği > Abonelikler bölümünden yönetebilirsiniz.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .padding(.horizontal)
        }
        .overlay(alignment: .bottom) {
            if showPurchaseToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Satın alma başarılı")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: subVM.isSubscribed) { _, newValue in
            if newValue {
                withAnimation(.spring()) { showPurchaseToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut) { showPurchaseToast = false }
                }
            }
        }
        .task {
            await subVM.loadProducts()
            await subVM.refreshEntitlements()
        }
        .foregroundColor(.white)
    }
}
    
