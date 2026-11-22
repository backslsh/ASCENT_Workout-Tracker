import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var step = 0
    @State private var name = ""
    @State private var age = 25
    @State private var weight: Double = 170
    @State private var units: UnitSystem = .lb
    @State private var sex: StandardSex = .male
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            if step == 0 {
                welcome.transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                form.transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: step)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.15)) { appeared = true } }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    RankBadge(rank: .display([RankTier.gold, .diamond, .legend][i]), size: 70)
                        .offset(x: CGFloat(i - 1) * 74, y: appeared ? CGFloat(abs(i - 1)) * 18 : 80)
                        .scaleEffect(i == 1 ? 1.25 : 1)
                        .opacity(appeared ? 1 : 0)
                        .zIndex(i == 1 ? 1 : 0)
                }
            }
            .frame(height: 120)

            VStack(spacing: 10) {
                Text("Ascend")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                Text("Lift. Log. Rank up.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            VStack(alignment: .leading, spacing: 14) {
                feature("dumbbell.fill", "Track gym & home workouts", "Barbells, dumbbells, bodyweight, core & holds.")
                feature("trophy.fill", "Earn ranks for every lift", "Iron to Legend, scored against your bodyweight.")
                feature("timer", "Built-in workout & rest timers", "Auto rest after each set, with alerts.")
                feature("lock.shield.fill", "Private & free", "No account. Everything stays on your phone.")
            }
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)

            Spacer()
            PrimaryButton(title: "Get Started", symbol: "arrow.right") { step = 1 }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(sub).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("About you").font(.system(size: 34, weight: .bold, design: .rounded)).padding(.top, 30)
                Text("Ranks are calculated relative to your bodyweight, so accuracy matters. You can change this anytime.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                field("Name") {
                    TextField("Your name", text: $name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                }

                field("Units") {
                    Picker("Units", selection: $units) {
                        Text("lb").tag(UnitSystem.lb)
                        Text("kg").tag(UnitSystem.kg)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: units) { old, new in
                        weight = (new.display(old.toKg(weight))).rounded()
                    }
                }

                HStack(spacing: 12) {
                    field("Age") {
                        Stepper(value: $age, in: 10...100) {
                            Text("\(age)").font(.title3.weight(.semibold)).monospacedDigit()
                        }
                    }
                    field("Weight (\(units.rawValue))") {
                        NumberField(value: $weight)
                            .font(.title3.weight(.semibold))
                            .frame(height: 30)
                    }
                    .frame(width: 130)
                }

                field("Rank standards") {
                    Picker("Standards", selection: $sex) {
                        Text("Male").tag(StandardSex.male)
                        Text("Female").tag(StandardSex.female)
                    }
                    .pickerStyle(.segmented)
                }

                PrimaryButton(title: "Start Lifting", symbol: "bolt.fill") { finish() }
                    .padding(.top, 10)
                    .disabled(weight <= 0)
                Button("Back") { step = 0 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 18)
    }

    private func finish() {
        hideKeyboard()
        var p = store.profile
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.age = age
        p.units = units
        p.bodyweight = max(30, units.toKg(weight))
        p.sex = sex
        p.onboarded = true
        Haptics.success()
        store.profile = p
        Notifier.request()
    }
}
