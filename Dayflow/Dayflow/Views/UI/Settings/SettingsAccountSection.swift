import SwiftUI

struct SettingsAccountSection: View {
  @ObservedObject private var authManager = DayflowAuthManager.shared
  @State private var isAuthSheetPresented = false
  @State private var selectedBillingInterval: DayflowBillingInterval = .yearly

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.sectionSpacing) {
      accountSection

      if authManager.entitlements.status == "active" {
        currentPlanSection
      } else {
        upgradeSection
      }

      if let errorText = authManager.errorText {
        Text(errorText)
          .font(.custom("Nunito", size: 11))
          .foregroundColor(SettingsStyle.destructive)
          .textSelection(.enabled)
      }
    }
    .sheet(isPresented: $isAuthSheetPresented) {
      DayflowSignInSheet {
        isAuthSheetPresented = false
      }
      .frame(width: 430)
    }
    .task {
      authManager.loadStoredSessionIfNeeded()
    }
  }

  private var accountSection: some View {
    SettingsSection(
      title: "Account",
      subtitle: "Sign in once to keep Dayflow Pro and cloud features attached to this Mac."
    ) {
      VStack(alignment: .leading, spacing: 0) {
        SettingsRow(
          label: "Dayflow account",
          subtitle: authManager.isSignedIn
            ? authManager.displayIdentity
            : "Use your email. No password, browser, or API keys.",
          showsDivider: authManager.isSignedIn
        ) {
          HStack(spacing: 8) {
            SettingsStatusDot(
              state: authManager.isSignedIn ? .good : .warn,
              label: authManager.isSignedIn ? "Signed in" : "Signed out"
            )

            if authManager.isSignedIn {
              SettingsSecondaryButton(
                title: "Refresh",
                systemImage: "arrow.clockwise",
                isDisabled: authManager.isBusy,
                action: { Task { await authManager.refreshAccount() } }
              )
            } else {
              SettingsPrimaryButton(
                title: "Sign in",
                systemImage: "person.crop.circle",
                isLoading: authManager.isBusy && authManager.hasLoadedStoredSession == false,
                action: { isAuthSheetPresented = true }
              )
            }
          }
        }
      }
    }
  }

  private var currentPlanSection: some View {
    SettingsSection(
      title: "Current plan",
      subtitle: "Your Pro access is active on this account."
    ) {
      SettingsRow(
        label: "Plan",
        subtitle: currentPlanSubtitle,
        showsDivider: false
      ) {
        SettingsStatusDot(
          state: .good,
          label: authManager.entitlements.displayName
        )
      }
    }
  }

  private var upgradeSection: some View {
    SettingsSection(
      title: "Upgrade to Dayflow Pro",
      subtitle: "Pick a plan, then finish securely in Stripe Checkout."
    ) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 12) {
          BillingPlanCard(
            title: "Monthly",
            price: "$18",
            cadence: "/mo",
            note: "Flexible monthly billing.",
            badge: nil,
            isSelected: selectedBillingInterval == .monthly
          ) {
            withAnimation(.easeOut(duration: 0.16)) {
              selectedBillingInterval = .monthly
            }
          }

          BillingPlanCard(
            title: "Yearly",
            price: "$180",
            cadence: "/yr",
            note: "$15/mo effective. Save $36.",
            badge: "2 months free",
            isSelected: selectedBillingInterval == .yearly
          ) {
            withAnimation(.easeOut(duration: 0.16)) {
              selectedBillingInterval = .yearly
            }
          }
        }

        ProFeatureList()

        HStack(alignment: .center, spacing: 12) {
          SettingsPrimaryButton(
            title: authManager.isSignedIn ? "Start 14-day trial" : "Sign in to upgrade",
            systemImage: authManager.isSignedIn ? "creditcard" : "person.crop.circle",
            isLoading: authManager.isBusy,
            action: upgradeAction
          )

          Text(upgradeFootnote)
            .font(.custom("Nunito", size: 12))
            .foregroundColor(SettingsStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var currentPlanSubtitle: String {
    if let currentPeriodEnd = authManager.entitlements.currentPeriodEnd, !currentPeriodEnd.isEmpty {
      return "Renews through \(currentPeriodEnd)."
    }
    return "Active on this account."
  }

  private var upgradeFootnote: String {
    switch selectedBillingInterval {
    case .monthly:
      return "14 days free, then $18/month. Cancel anytime in Stripe."
    case .yearly:
      return "14 days free, then $180/year. Best value."
    }
  }

  private func upgradeAction() {
    guard authManager.isSignedIn else {
      isAuthSheetPresented = true
      return
    }

    Task {
      await authManager.openBillingCheckout(interval: selectedBillingInterval)
    }
  }
}

private struct BillingPlanCard: View {
  let title: String
  let price: String
  let cadence: String
  let note: String
  let badge: String?
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(title)
            .font(.custom("Nunito", size: 13))
            .fontWeight(.bold)
            .foregroundColor(SettingsStyle.text)

          Spacer(minLength: 8)

          if let badge {
            SettingsBadge(text: badge.uppercased(), isAccent: true)
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(price)
            .font(.custom("InstrumentSerif-Regular", size: 38))
            .foregroundColor(SettingsStyle.text)
          Text(cadence)
            .font(.custom("Nunito", size: 13))
            .fontWeight(.semibold)
            .foregroundColor(SettingsStyle.secondary)
        }

        Text(note)
          .font(.custom("Nunito", size: 12))
          .foregroundColor(SettingsStyle.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? SettingsStyle.ink.opacity(0.06) : Color.white.opacity(0.55))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(isSelected ? SettingsStyle.ink.opacity(0.8) : SettingsStyle.divider, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
  }
}

private struct ProFeatureList: View {
  private let features = [
    "Zero setup cloud AI for timeline generation",
    "Daily and weekly reports without provider setup",
    "Processed securely and never used to train AI models",
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(features, id: \.self) { feature in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(SettingsStyle.statusGood)
            .padding(.top, 1)

          Text(feature)
            .font(.custom("Nunito", size: 12))
            .foregroundColor(SettingsStyle.text)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.top, 2)
  }
}

private struct DayflowSignInSheet: View {
  private enum Step {
    case email
    case code
  }

  private enum Field {
    case email
    case code
  }

  @ObservedObject private var authManager = DayflowAuthManager.shared
  @FocusState private var focusedField: Field?

  let onDismiss: () -> Void

  @State private var step: Step = .email
  @State private var emailAddress = ""
  @State private var verificationCode = ""
  @State private var didAutoSubmitCode = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header

      switch step {
      case .email:
        emailForm
      case .code:
        codeForm
      }

      if let errorText = authManager.errorText {
        Text(errorText)
          .font(.custom("Nunito", size: 12))
          .foregroundColor(SettingsStyle.destructive)
          .textSelection(.enabled)
      }
    }
    .padding(26)
    .background(Color.white)
    .onAppear {
      emailAddress = authManager.signedInEmail ?? emailAddress
      focusedField = step == .email ? .email : .code
    }
    .onChange(of: authManager.isSignedIn) { _, isSignedIn in
      guard isSignedIn else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        onDismiss()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(step == .email ? "Sign in to Dayflow" : "Check your email")
        .font(.custom("InstrumentSerif-Regular", size: 30))
        .foregroundColor(SettingsStyle.text)

      Text(
        step == .email
          ? "Enter your email and Dayflow will send a 6 digit code."
          : "Enter the code sent to \(authManager.pendingEmail ?? emailAddressTrimmed)."
      )
      .font(.custom("Nunito", size: 13))
      .foregroundColor(SettingsStyle.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var emailForm: some View {
    VStack(alignment: .leading, spacing: 14) {
      TextField("you@example.com", text: $emailAddress)
        .textFieldStyle(.roundedBorder)
        .font(.custom("Nunito", size: 14))
        .focused($focusedField, equals: .email)
        .disabled(authManager.isBusy)
        .onSubmit { sendCode() }

      HStack(spacing: 10) {
        SettingsPrimaryButton(
          title: "Continue",
          systemImage: "arrow.right",
          isLoading: authManager.isBusy,
          isDisabled: emailAddressTrimmed.isEmpty,
          action: sendCode
        )

        SettingsSecondaryButton(
          title: "Cancel",
          isDisabled: authManager.isBusy,
          action: onDismiss
        )
      }
    }
  }

  private var codeForm: some View {
    VStack(alignment: .leading, spacing: 14) {
      TextField("000000", text: $verificationCode)
        .textFieldStyle(.plain)
        .font(.system(size: 30, weight: .semibold, design: .monospaced))
        .multilineTextAlignment(.center)
        .tracking(8)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.04))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(SettingsStyle.divider, lineWidth: 1)
        )
        .focused($focusedField, equals: .code)
        .disabled(authManager.isBusy)
        .onChange(of: verificationCode) { _, newValue in
          let digits = String(newValue.filter(\.isNumber).prefix(6))
          if digits != newValue {
            verificationCode = digits
          }
          guard digits.count == 6, !didAutoSubmitCode, !authManager.isBusy else { return }
          didAutoSubmitCode = true
          verifyCode()
        }
        .onSubmit { verifyCode() }

      HStack(spacing: 10) {
        SettingsPrimaryButton(
          title: "Verify",
          systemImage: "checkmark",
          isLoading: authManager.isBusy,
          isDisabled: verificationCodeTrimmed.count != 6,
          action: verifyCode
        )

        SettingsSecondaryButton(
          title: "Resend",
          isDisabled: authManager.isBusy,
          action: {
            Task {
              didAutoSubmitCode = false
              verificationCode = ""
              await authManager.resendCode()
              focusedField = .code
            }
          }
        )

        SettingsSecondaryButton(
          title: "Change email",
          isDisabled: authManager.isBusy,
          action: {
            authManager.useDifferentEmail()
            verificationCode = ""
            didAutoSubmitCode = false
            step = .email
            focusedField = .email
          }
        )
      }
    }
  }

  private func sendCode() {
    guard !emailAddressTrimmed.isEmpty else { return }
    Task {
      await authManager.sendCode(to: emailAddressTrimmed)
      if authManager.canVerifyCode, authManager.errorText == nil {
        verificationCode = ""
        didAutoSubmitCode = false
        step = .code
        focusedField = .code
      }
    }
  }

  private func verifyCode() {
    guard verificationCodeTrimmed.count == 6 else { return }
    Task {
      await authManager.verifyCode(verificationCodeTrimmed)
      if authManager.errorText != nil {
        didAutoSubmitCode = false
      }
    }
  }

  private var emailAddressTrimmed: String {
    emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var verificationCodeTrimmed: String {
    String(verificationCode.filter(\.isNumber).prefix(6))
  }
}
