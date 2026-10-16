import SwiftUI

@MainActor
struct PrivacyView: View {
    @ObservedObject var consent: PrivacyConsentViewModel
    let onWithdraw: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(consent.isGranted ? "Your privacy choices" : "Before you translate")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text(PrivacyPolicy.disclosure)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink("Read the Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    .accessibilityHint("Read processing, storage, retention, and withdrawal details without leaving the app")

                    Link("Project support (public GitHub)", destination: PrivacyPolicy.supportURL)
                    Text(PrivacyPolicy.publicSupportWarning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if consent.isGranted {
                        Button("Withdraw permission and clear current data", role: .destructive) {
                            onWithdraw()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Stops client work, attempts to delete pending recordings, and clears current input and results; data already sent cannot be recalled")
                    } else {
                        Button("Allow translation processing") {
                            consent.allow()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint("Allows text and audio processing for this app session; does not start recording or send a translation")

                        Button("Not now") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Keeps translation processing off")
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AmharicVoice AI Privacy Policy")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Updated \(PrivacyPolicy.version)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(PrivacyPolicy.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(section.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                Link("Open public project support", destination: PrivacyPolicy.supportURL)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
