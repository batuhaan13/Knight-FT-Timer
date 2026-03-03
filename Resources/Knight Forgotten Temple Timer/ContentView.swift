//
//  ContentView.swift
//  Knight Forgotten Temple Timer
//
//  Created by Batuhan Kasar on 26.01.2026.
//

import SwiftUI
import AVFoundation
import Combine

import UIKit


final class SoundManager {
    static let shared = SoundManager()
    private var bipPlayer: AVAudioPlayer?
    private var spawnPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
        preload()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func preload() {
        bipPlayer = load(name: "bip", ext: "mp3")
        spawnPlayer = load(name: "spawn", ext: "mp3")
    }

    private func load(name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Sound not found in bundle: \(name).\(ext)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to load sound: \(name).\(ext) -> \(error)")
            return nil
        }
    }

    func playBeep() { bipPlayer?.play() }
    func playSpawn() { spawnPlayer?.play() }
}

final class FTTimerViewModel: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    
    @Published var showResetToast: Bool = false
    @Published var resetMessage: String = ""
    
    enum Mode { case ft, pooka, m2210, m2215, none }
    @Published private(set) var activeMode: Mode = .none
    @Published private(set) var remainingString: String = ""
    @Published private(set) var currentEventName: String = ""
    
    private var timer: Timer?
    private var firedKeys = Set<String>()
    private var isPookaMode: Bool = false
    private var firedGlobalKeys = Set<String>()

    // 26 dakika
    private let totalDuration: TimeInterval = 26 * 60

    // Event listesi: mm:ss -> isim
    private let eventSpecs: [(minutes: Int, seconds: Int, name: String)] = [
        (6,0,"Pooka"),(6,12,"Lard Orc"),(6,47,"Orc Archer"),(7,0,"Trol Berserker"),(7,12,"Baron"),(7,47,"Death Knight"),(8,0,"Crimson Wing"),(8,12,"Scolar"),(8,17,"Tyoon"),(8,30,"Troll"),(9,17,"Ash Knight"),(9,30,"Haunga"),(10,0,"Deruvish"),(10,12,"Lamia"),(10,35,"Urak Hai"),(10,47,"Harppy"),(11,0,"Dragon Tooth Knight"),(11,35,"Uruk Tron"),(11,47,"Wraith"),(12,30,"Apostle"),(12,47,"Garuna"),(13,17,"Lamiros"),(13,30,"Deruvish"),(14,0,"Blood seeker"),(14,12,"Orc Sniper"),(14,17,"Stone Golem"),(14,30,"Haunga"),(14,41,"Bugger"),(15,17,"Raven Harpy"),(15,30,"Sheriff"),(15,35,"Dragon Tooth Knight"),(16,47,"Lamenation"),(17,0,"Dark Stone"),(17,12,"Lich"),(18,0,"Hob Goblin"),(18,12,"Troll"),(18,17,"Uruk Tron"),(19,40,"Sheriff"),(19,47,"Manticore"),(20,0,"Burning Skeleton"),(20,12,"Lamia"),(20,47,"Fallen Angel"),(21,0,"Grell"),(21,12,"Mastedon"),(22,12,"Centaur"),(22,17,"Goblin Bauncer"),(22,37,"Harrpy"),(23,17,"Tyoon"),(23,30,"Stone Golem"),(23,37,"Beast"),(24,35,"Giant Golem"),(24,47,"Haunga Warrior"),(25,17,"Troll Warrior"),(25,30,"Reaper"),(25,37,"Dark Mare")
    ]

    private var events: [(date: Date, name: String)] = []
    
    private func playImmediateCountdown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) { SoundManager.shared.playBeep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { SoundManager.shared.playBeep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { SoundManager.shared.playBeep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { SoundManager.shared.playBeep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { SoundManager.shared.playSpawn() }
    }

    func startIfNeeded() {
        if isRunning {
            // Second tap: reset everything to avoid overlap
            reset()
            return
        }
        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(totalDuration)
        isRunning = true
        activeMode = .ft
        firedKeys.removeAll()
        isPookaMode = false
        firedGlobalKeys.removeAll()
        buildEvents()
        // Removed the playImmediateCountdown() call here as per instructions
        startTicker()
    }

    func startPookaIfNeeded() {
        if isRunning {
            // Second tap: reset everything to avoid overlap
            reset()
            return
        }
        let now = Date()
        startDate = now // start immediately
        endDate = now.addingTimeInterval(20 * 60) // 20 minutes window
        isRunning = true
        activeMode = .pooka
        firedKeys.removeAll()
        firedGlobalKeys.removeAll()
        isPookaMode = true
        buildPookaEvents()
        startTicker()
    }
    
    func start2210IfNeeded() {
        if isRunning {
            reset()
            return
        }
        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(15 * 60) // 15 minutes window
        isRunning = true
        activeMode = .m2210
        firedKeys.removeAll()
        firedGlobalKeys.removeAll()
        isPookaMode = false // treat as normal event-driven mode
        build2210Events()
        startTicker()
    }
    
    func start2215IfNeeded() {
        if isRunning {
            reset()
            return
        }
        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(10 * 60) // 10 minutes window
        isRunning = true
        activeMode = .m2215
        firedKeys.removeAll()
        firedGlobalKeys.removeAll()
        isPookaMode = false
        build2215Events()
        startTicker()
    }

    private func buildEvents() {
        guard let start = startDate else { return }
        events = eventSpecs.map { spec in
            let offset = TimeInterval(spec.minutes * 60 + spec.seconds)
            return (date: start.addingTimeInterval(offset), name: spec.name)
        }
    }

    private func buildPookaEvents() {
        guard let start = startDate else { return }
        let specs: [(Int, Int, String)] = [
            (0,0,"Pooka"),(0,12,"Lard Orc"),(0,47,"Orc Archer"),(1,0,"Troll Warrior"),(1,12,"Baron"),(1,47,"Death Knight"),(2,0,"Crimson Wing"),(2,12,"Scolar"),(2,17,"Tyoon"),(2,30,"Troll"),(3,17,"Ash Knight"),(3,30,"Haunga"),(4,0,"Deruvish"),(4,12,"Lamia"),(4,35,"Urak Hai"),(4,47,"Harppy"),(5,0,"Dragon Tooth Knight"),(5,35,"Uruk Tron"),(5,47,"Wraith"),(6,30,"Apostle"),(6,47,"Garuna"),(7,17,"Lamiros"),(7,30,"Deruvish"),(8,0,"Blood Seeker"),(8,12,"Orc Sniper"),(8,17,"Stone Golem"),(8,26,"Haunga"),(8,41,"Bugger"),(9,17,"Raven Harpy"),(9,30,"Sheriff"),(9,35,"Dragon Tooth Knight"),(10,47,"Lamenation"),(11,0,"Dark Stone"),(11,12,"Lich"),(12,0,"Hob Goblin"),(12,12,"Troll"),(12,17,"Uruk Tron"),(13,40,"Sheriff"),(13,47,"Manticore"),(14,0,"Burning Skeleton"),(14,12,"Lamia"),(14,47,"Fallen Angel"),(15,0,"Grell"),(15,12,"Mastedon"),(16,12,"Centaur"),(16,17,"Goblin Bouncer"),(16,37,"Harrpy"),(17,17,"Tyoon"),(17,30,"Stone Golem"),(17,37,"Beast"),(18,35,"Giant Golem"),(18,47,"Haunga Warrior"),(19,17,"Troll Warrior"),(19,30,"Reaper"),(19,37,"Dark Mare")
        ]
        events = specs.map { (m,s,name) in
            let offset = TimeInterval(m * 60 + s)
            return (date: start.addingTimeInterval(offset), name: name)
        }
    }
    
    private func build2210Events() {
        guard let start = startDate else { return }
        let specs: [(Int, Int, String)] = [
            (0,0,"Lamenation"),(0,13,"Dark Stone"),(0,25,"Lich"),(1,13,"Hob Goblin"),(1,25,"Troll"),(1,30,"Uruk Tron"),(2,53,"Sheriff"),(3,0,"Manticore"),(3,13,"Burning Skeleton"),(3,25,"Lamia"),(4,0,"Fallen Angel"),(4,13,"Grell"),(4,25,"Mastadon"),(5,25,"Centaur"),(5,30,"Goblin Bouncer"),(5,50,"Harrpy"),(6,30,"Tyoon"),(6,43,"Stone Golem"),(6,50,"Beast"),(7,48,"Giant Golem"),(8,0,"Haunga Warrior"),(8,30,"Troll Warrior"),(8,43,"Reaper"),(8,50,"Dark Mare")
        ]
        events = specs.map { (m,s,name) in
            let offset = TimeInterval(m * 60 + s)
            return (date: start.addingTimeInterval(offset), name: name)
        }
    }

    private func build2215Events() {
        guard let start = startDate else { return }
        let specs: [(Int, Int, String)] = [
            (0,0,"Grell"),
            (0,12,"Mastadon"),
            (1,12,"Centaur"),
            (1,17,"Goblin Bouncer"),
            (1,37,"Harrpy"),
            (2,17,"Tyoon"),
            (2,30,"Stone Golem"),
            (2,37,"Beast"),
            (3,35,"Giant Golem"),
            (3,47,"Haunga Warrior"),
            (4,17,"Troll Warrior"),
            (4,30,"Reaper"),
            (4,37,"Dark Mare")
        ]
        events = specs.map { (m,s,name) in
            let offset = TimeInterval(m * 60 + s)
            return (date: start.addingTimeInterval(offset), name: name)
        }
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tick() {
        guard let end = endDate else { return }
        let now = Date()
        if let endDate {
            let remaining = max(0, Int(endDate.timeIntervalSince(now)))
            let m = remaining / 60
            let s = remaining % 60
            remainingString = String(format: "%02d:%02d", m, s)
            print(String(format: "Kalan süre: %02d:%02d", m, s))
            handleGlobalPookaCountdown(remaining: remaining)
        }
        fireEventsIfNeeded(now: now)
        if now >= end {
            // Süre dolunca sadece koşuyu bitir, butona tekrar basılsa bile durdurma yok; yeni start ayrı tetiklenir.
            timer?.invalidate()
            timer = nil
            isRunning = false
        }
    }

    private func fireEventsIfNeeded(now: Date) {
        // Tolerans ±0.15s, öncelik: gonk(=T-4 beep) -> beep -> spawn
        let tol: TimeInterval = 0.15
        for (date, name) in events {
            let delta = date.timeIntervalSince(now)
            // T-4: bip
            if abs(delta - 4.0) <= tol { fireOnce(key: "\(name)_b4") { SoundManager.shared.playBeep() } }
            // T-3,2,1: bip
            if abs(delta - 3.0) <= tol { fireOnce(key: "\(name)_b3") { SoundManager.shared.playBeep() } }
            if abs(delta - 2.0) <= tol { fireOnce(key: "\(name)_b2") { SoundManager.shared.playBeep() } }
            if abs(delta - 1.0) <= tol { fireOnce(key: "\(name)_b1") { SoundManager.shared.playBeep() } }
            // T=0: spawn
            if abs(delta - 0.0) <= tol {
                fireOnce(key: "\(name)_spawn") { [weak self] in
                    SoundManager.shared.playSpawn()
                    guard let self = self else { return }
                    self.currentEventName = name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        guard let self = self else { return }
                        if self.currentEventName == name { self.currentEventName = "" }
                    }
                }
            }
        }
    }

    private func fireOnce(key: String, action: () -> Void) {
        guard !firedKeys.contains(key) else { return }
        firedKeys.insert(key)
        action()
    }
    
    private func handleGlobalPookaCountdown(remaining: Int) {
        guard isPookaMode else { return }
        // We want beeps at 22:04, 22:03, 22:02, 22:01 and spawn at 22:00 (from global remaining time)
        // Convert target times to seconds
        let targetsBeep: [Int] = [4, 3, 2, 1]
        let targetSpawn: Int = 0
        let tol = 0 // use exact integer matching since remaining is Int
        for t in targetsBeep {
            if abs(remaining - t) <= tol {
                fireGlobalOnce(key: "global_b_\(t)") { SoundManager.shared.playBeep() }
            }
        }
        if abs(remaining - targetSpawn) <= tol {
            fireGlobalOnce(key: "global_spawn_\(targetSpawn)") { SoundManager.shared.playSpawn() }
        }
    }

    private func fireGlobalOnce(key: String, action: () -> Void) {
        guard !firedGlobalKeys.contains(key) else { return }
        firedGlobalKeys.insert(key)
        action()
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startDate = nil
        endDate = nil
        firedKeys.removeAll()
        firedGlobalKeys.removeAll()
        events.removeAll()
        activeMode = .none
        remainingString = ""
        currentEventName = ""
        print("Timer reset")
        resetMessage = "Sayaç durduruldu ve sıfırlandı"
        showResetToast = true
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

struct PulsingDotsView: View {
    private let dotCount = 3

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let speed = 1.25 // cycles per second
            let phase = t * speed

            HStack(spacing: 10) {
                ForEach(0..<dotCount, id: \.self) { index in
                    let delay = Double(index) * 0.25
                    let value = sin((phase * .pi * 2) - delay * .pi)

                    Circle()
                        .fill(Color.green.opacity(0.95))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color.green.opacity(0.9), radius: 6, x: 0, y: 0)
                        .scaleEffect(0.975 + 0.175 * CGFloat(value))
                        .offset(y: -2 * CGFloat(value))
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var subVM = SubscriptionViewModel()
    @State private var showPaywall = false
    @StateObject private var vm = FTTimerViewModel()
    @State private var hasShownPaywall = false
    @State private var notificationsOn: Bool = false
    @State private var showNotificationSettingsAlert: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.2) // Lacivert arka plan
                .ignoresSafeArea()
            VStack {
                // Üst başlık
                PulsingDotsView()
                    .padding(.bottom, 2)
                Text("⏳FT Timer - PRO")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                    .textCase(nil)
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                // FT GİRİŞ kartı
                Button {
                    if !subVM.isSubscribed {
                        showPaywall = true
                        return
                    }
                    vm.startIfNeeded()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(vm.activeMode == .ft && vm.isRunning ? (vm.currentEventName.isEmpty ? vm.remainingString : vm.currentEventName) : "🎯FT GİRİŞ 1 DK ÖNCESİ")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .frame(maxWidth: .infinity, minHeight: 90)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.9),
                                        Color.blue.opacity(0.9),
                                        Color.pink.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        if !subVM.isSubscribed {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .pink.opacity(0.55), radius: 2, x: 0, y: 1)
                                Text("PRO")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 3)
                            .background(Color.pink.gradient, in: Capsule())
                            .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 2)
                            .padding(10)
                        }
                    }
                    .opacity(subVM.isSubscribed ? 1.0 : 0.55)
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)

                // POOKA DALGASI BAŞLANGICI kartı
                Button {
                    if !subVM.isSubscribed {
                        showPaywall = true
                        return
                    }
                    vm.startPookaIfNeeded()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(vm.activeMode == .pooka && vm.isRunning ? (vm.currentEventName.isEmpty ? vm.remainingString : vm.currentEventName) : "🐵POOKA DALGASI BAŞLANGICI")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .frame(maxWidth: .infinity, minHeight: 90)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(0.9),
                                        Color.green.opacity(0.6),
                                        Color.pink.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        if !subVM.isSubscribed {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .pink.opacity(0.55), radius: 2, x: 0, y: 1)
                                Text("PRO")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 3)
                            .background(Color.pink.gradient, in: Capsule())
                            .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 2)
                            .padding(10)
                        }
                    }
                    .opacity(subVM.isSubscribed ? 1.0 : 0.55)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                
                HStack {
                    Toggle(isOn: $notificationsOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Etkinlik Hatırlatmaları")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.green.opacity(0.8))
                            Text("Her gün 02:50 ve 21:50'de bildirim gönder")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .tint(Color.pink)
                }
                .padding()
                .background(Color.white.opacity(0.12))
                .cornerRadius(14)
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .onChange(of: notificationsOn) { _, newValue in
                    Task {
                        if newValue {
                            let granted = await NotificationManager.requestAuthorization()
                            if granted {
                                await NotificationManager.scheduleDailyReminders()
                            } else {
                                // Turn back off if not granted
                                await MainActor.run {
                                    notificationsOn = false
                                    showNotificationSettingsAlert = true
                                }
                            }
                        } else {
                            await NotificationManager.removeDailyReminders()
                        }
                    }
                }
                .alert("Bildirim İzni Gerekli", isPresented: $showNotificationSettingsAlert) {
                    Button("Ayarlar") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("İptal", role: .cancel) { }
                } message: {
                    Text("Daha önce bildirim iznini reddettiniz. Tekrar izin isteyemiyoruz. Bildirimleri açmak için Ayarlar > Bildirimler'den izin verin ve bu ekrana geri dönün.")
                }
                .task {
                    let enabled = await NotificationManager.notificationsEnabled()
                    await MainActor.run { notificationsOn = enabled }
                }
                
                
                // Dalga 1-4 grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    Button(vm.activeMode == .m2210 && vm.isRunning ? (vm.currentEventName.isEmpty ? vm.remainingString : vm.currentEventName) : "22:10 & 03:10 ") {
                        vm.start2210IfNeeded()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(0.3)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.white.opacity(0.25))
                    .foregroundStyle(.white)
                    .cornerRadius(14)

                    Button(vm.activeMode == .m2215 && vm.isRunning ? (vm.currentEventName.isEmpty ? vm.remainingString : vm.currentEventName) : "22.15 & 03.15 ") {
                        vm.start2215IfNeeded()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(0.3)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.white.opacity(0.25))
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)
            }
            .overlay(alignment: .bottom) {
                if vm.showResetToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.white)
                        Text(vm.resetMessage)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
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
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut) {
                                vm.showResetToast = false
                            }
                        }
                    }
                }
            }
            .padding(-19)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    let enabled = await NotificationManager.notificationsEnabled()
                    await MainActor.run { notificationsOn = enabled }
                }
            }
        }
        .task {
            await subVM.loadProducts()
            await subVM.refreshEntitlements()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subVM: subVM)
                .onChange(of: subVM.isSubscribed) { _, newValue in
                    if newValue {
                        showPaywall = false
                    }
                }
                .onDisappear {
                    hasShownPaywall = true
                }
        }
    }
}

#Preview {
    ContentView()
}

