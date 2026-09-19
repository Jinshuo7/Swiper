import SwiftUI

struct PermissionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.white)
            Text("Photo access")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
            Text("Swiper needs access to your photo library to show each photo, mark favorites and delete the photos you explicitly confirm. Everything stays on this device — nothing is uploaded, and Swiper never deletes anything until you confirm it in the deletion review.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                switch model.authorization {
                case .notDetermined:
                    Button {
                        Task { await model.requestAccess() }
                    } label: {
                        Label("Allow Photo Access", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("permission.allow")
                case .denied, .restricted:
                    Button {
                        model.openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("permission.settings")
                case .limited, .authorized:
                    EmptyView()
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .disabled(model.isBusy)
    }
}
