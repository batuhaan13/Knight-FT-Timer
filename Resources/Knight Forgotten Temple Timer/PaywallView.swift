import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subVM: SubscriptionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showPurchaseToast: Bool = false

    private let privacyPolicyURL = URL(string: "https://batuhaan13.github.io/Knight-FT-Timer/")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.2).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    Text("FT Timer Premium 👑")
                        .font(.system(size: 30, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .padding(.top, 64)

                    VStack(spacing: 6) {
                        Text("Aylık otomatik yenilenen abonelik")
                            .font(.footnote.weight(.semibold))

                        Text("7 gün ücretsiz deneme")
                            .font(.footnote.bold())

                        Text("Deneme süresi bitince abonelik otomatik olarak yenilenir.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))

                        Text("İstediğin zaman iptal edebilirsin.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium ile şunları açarsın:")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Group {
                            Text("• Tüm FT dalga ve boss zamanlayıcıları")
                            Text("• Dalga başlangıçları için hassas geri sayım")
                            Text("• Kritik anlar için zamanında uyarılar")
                            Text("• Kritik anlar için zamanında uyarılar")
                            Text("• Etkinlik boyunca kesintisiz takip ve kontrol")
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                        Text("Premium olmadan bu özellikler sınırlıdır.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                    // MARK: - Purchase area
                    if subVM.isLoading {
                        ProgressView("Ürün yükleniyor…")
                            .tint(.white)
                            .padding(.top, 4)
                    } else {
                        if let product = subVM.currentProduct {
                            Button("\(product.displayPrice) / ay ile devam et") {
                                Task { await subVM.purchaseCurrent() }
                            }
                            .font(.system(.title3, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.pink.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .disabled(subVM.isLoading) // ✅ sadeleştirildi
                        } else {
                            Button("Ürün yüklenemedi, tekrar dene") {
                                Task { await subVM.reloadProducts() }
                            }
                            .font(.system(.title3, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.pink.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .disabled(subVM.isLoading)
                        }
                    }

                    Button("Satın alımları geri yükle") {
                        Task { await subVM.restore() }
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.white.opacity(0.7))
                    .padding(.top, 2)
                    .disabled(subVM.isLoading)

                    if let error = subVM.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    #if DEBUG
                    Text("Debug: products=\(subVM.products.count), loading=\(subVM.isLoading)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                    #endif

                    Text("Fiyat bölgenize göre değişiklik gösterebilir. Abonelik otomatik yenilenir. Aboneliği Ayarlar > Apple Kimliği > Abonelikler bölümünden yönetebilirsiniz.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 6) {
                        Text("Devam ederek Şartlar ve Gizlilik Politikası’nı kabul etmiş olursunuz.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            Button { openURL(termsOfUseURL) } label: {
                                Text("Terms of Use (EULA)")
                                    .font(.caption.weight(.semibold))
                                    .underline()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }

                            Button { openURL(privacyPolicyURL) } label: {
                                Text("Privacy Policy")
                                    .font(.caption.weight(.semibold))
                                    .underline()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 2)

                    Spacer(minLength: 16)
                }
                .padding()
                .padding(.horizontal)
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 12)
            .zIndex(999)
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
        .onAppear {
            if subVM.currentProduct == nil && !subVM.isLoading {
                Task { await subVM.reloadProducts() }
            }
        }
        .foregroundColor(.white)
    }
}
