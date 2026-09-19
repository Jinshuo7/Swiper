import SwiftUI

struct EntryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                if model.resumableSession != nil {
                    Button {
                        model.resumeSession()
                    } label: {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("entry.resume")
                    .accessibilityHint("Resume Session")
                }

                Button {
                    model.startRecent()
                } label: {
                    Label("Recent", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(AdaptiveButtonStyle(isPrimary: model.resumableSession == nil))
                .accessibilityIdentifier("entry.recent")
                .disabled(!model.hasPhotos)

                Button {
                    model.showStartHere()
                } label: {
                    Label("Start Here", systemImage: "square.grid.2x2")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("entry.startHere")
                .disabled(!model.hasPhotos)

                Button {
                    model.startTumbler()
                } label: {
                    Label("Tumbler", systemImage: "shuffle")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("entry.tumbler")
                .disabled(!model.hasPhotos)

                if model.authorization.isLimited {
                    Button {
                        model.manageLimitedLibrary()
                    } label: {
                        Label("Select More Photos", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("entry.selectMorePhotos")
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 12)

            Text("Swipe left to queue for deletion or right to keep.\nUse the heart to favorite. Videos are left alone.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.route = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("entry.settings")

            Spacer()

            Text("Swiper")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                model.route = .statistics
            } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Statistics")
            .accessibilityIdentifier("entry.statistics")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
