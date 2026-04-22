import SwiftUI

struct UploadPlansView: View {
    @ObservedObject var store: AppointmentStore

    @Environment(\.dismiss) private var dismiss

    @State private var activePlanPurchase: UploadPlan?
    @State private var isRestoringPurchases = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
                    Text("Choose a monthly upload plan.")
                        .font(LinearDesign.Typography.small)
                        .foregroundStyle(LinearDesign.Colors.secondaryText)

                    ForEach(UploadPlan.allCases) { plan in
                        planCard(for: plan)
                    }

                    Button {
                        restorePurchases()
                    } label: {
                        if isRestoringPurchases {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .padding(.vertical, LinearDesign.Spacing.xSmall)
                        } else {
                            Text("Restore purchases")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .padding(.vertical, LinearDesign.Spacing.xSmall)
                        }
                    }
                    .font(LinearDesign.Typography.bodyMedium)
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: LinearDesign.Radius.medium)
                            .stroke(LinearDesign.Colors.borderStandard, lineWidth: 1)
                    )
                    .disabled(isRestoringPurchases || activePlanPurchase != nil)

                    legalFooter
                }
                .padding(LinearDesign.Spacing.medium)
            }
            .background(LinearDesign.Colors.panelDark.ignoresSafeArea())
            .navigationTitle("Upload Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
                }
            }
            .alert("Subscription", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xSmall) {
            Text("Subscriptions auto-renew monthly until canceled. Manage or cancel anytime in your Apple ID settings at least 24 hours before the end of the current period.")
                .font(LinearDesign.Typography.caption)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: LinearDesign.Spacing.medium) {
                Link("Terms of Use (EULA)",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://pkid.github.io/githubpages/privacy.html")!)
            }
            .font(LinearDesign.Typography.captionMedium)
            .foregroundStyle(LinearDesign.Colors.accentViolet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, LinearDesign.Spacing.small)
    }

    private func planCard(for plan: UploadPlan) -> some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.small) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                    Text(plan.title)
                        .font(LinearDesign.Typography.bodySemibold)
                        .foregroundStyle(LinearDesign.Colors.primaryText)
                    if plan != .free {
                        Text("Auto-renewing monthly subscription")
                            .font(LinearDesign.Typography.caption)
                            .foregroundStyle(LinearDesign.Colors.tertiaryText)
                    }
                    Text(plan.summary)
                        .font(LinearDesign.Typography.small)
                        .foregroundStyle(LinearDesign.Colors.secondaryText)
                }

                Spacer()

                Text(plan == .free ? "Free" : "\(store.planPriceLabel(for: plan))/month")
                    .font(LinearDesign.Typography.smallMedium)
                    .foregroundStyle(LinearDesign.Colors.primaryText)
            }

            if plan == store.uploadPlan {
                Text("Current plan")
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.successGreen)
            } else if plan == .free {
                Text("Included by default.")
                    .font(LinearDesign.Typography.caption)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
            } else {
                Button {
                    subscribe(to: plan)
                } label: {
                    HStack(spacing: LinearDesign.Spacing.xSmall) {
                        if activePlanPurchase == plan {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(activePlanPurchase == plan ? "Processing..." : "Subscribe")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LinearButtonStyle(variant: .primary, isLoading: activePlanPurchase == plan))
                .disabled(activePlanPurchase != nil || isRestoringPurchases)

                if !store.canPurchase(plan) {
                    Text("Product info is still loading.")
                        .font(LinearDesign.Typography.caption)
                        .foregroundStyle(LinearDesign.Colors.tertiaryText)
                }
            }
        }
        .padding(LinearDesign.Spacing.medium)
        .linearCard()
    }

    private func subscribe(to plan: UploadPlan) {
        Task {
            activePlanPurchase = plan
            defer { activePlanPurchase = nil }

            do {
                try await store.purchase(plan: plan)
                dismiss()
            } catch let subscriptionError as SubscriptionError {
                if case .userCancelled = subscriptionError {
                    return
                }
                errorMessage = subscriptionError.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restorePurchases() {
        Task {
            isRestoringPurchases = true
            defer { isRestoringPurchases = false }

            do {
                try await store.restorePurchases()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
