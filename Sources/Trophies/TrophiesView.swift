import AppKit
import SwiftUI

/// The trophy hub in the home window: the same screens as the iPhone app, with a sidebar.
struct TrophiesView: View {
    enum Section: Int, CaseIterable, Identifiable {
        case profile, games, targets, friends, stats
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .profile: return M.profileTab
            case .games: return M.gamesTab
            case .targets: return M.targetsTab
            case .friends: return M.friendsTab
            case .stats: return M.statsTab
            }
        }
        var icon: String {
            switch self {
            case .profile: return "person"
            case .games: return "gamecontroller"
            case .targets: return "pin"
            case .friends: return "person.2"
            case .stats: return "chart.bar"
            }
        }
    }

    @State private var store = TrophyStore.shared
    @AppStorage("trophyHubSection") private var section = Section.profile.rawValue
    @AppStorage("accent") private var accent = 0

    var body: some View {
        Group {
            if store.signedIn {
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    page
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Style.backdrop)
                // The hub is always dark, like the phone app, whatever the Mac's appearance.
                .preferredColorScheme(.dark)
            } else {
                SignInView(store: store)
            }
        }
        .tint(Style.glow)
        .id(accent)
        .frame(minWidth: 1040, minHeight: 600)
        .task { await store.load() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Section.allCases) { item in
                Button {
                    section = item.rawValue
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.body.weight(section == item.rawValue ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(section == item.rawValue ? Style.glow.opacity(0.22) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 210)
    }

    @ViewBuilder
    private var page: some View {
        switch Section(rawValue: section) ?? .profile {
        case .profile: ProfileView()
        case .games: GamesView()
        case .targets: TargetsView()
        case .friends: FriendsView()
        case .stats: StatsView()
        }
    }
}

struct RemoteIcon: View {
    let url: URL?
    let size: CGFloat
    /// Images supplied up front by the preview renderer, which can't wait for downloads.
    nonisolated(unsafe) static var preloaded: [URL: NSImage] = [:]

    var body: some View {
        Group {
            if let url, let image = Self.preloaded[url] {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 60 ? 10 : 6))
    }
}

// MARK: - Sign in

struct SignInView: View {
    let store: TrophyStore
    @State private var token = ""
    @State private var manual = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trophy.circle.fill").font(.system(size: 54)).foregroundStyle(.tint)
            Text(S.connectPSN).font(.title2.bold())
            Text(S.connectIntroShort)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button {
                PSNWebLogin.shared.begin(
                    onCode: { code in Task { await store.signIn(authorizationCode: code) } },
                    onToken: { token in Task { await store.signIn(sessionToken: token) } })
            } label: {
                Label(S.signInWithPlayStation, systemImage: "person.badge.key")
                    .frame(minWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.loading)
            if store.loading { ProgressView().controlSize(.small) }
            if let problem = store.problem {
                Text(problem).foregroundStyle(.red).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            DisclosureGroup(S.advancedManualToken, isExpanded: $manual) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(S.manualStep)
                        Button(S.openPage) { NSWorkspace.shared.open(PSNClient.sessionTokenURL) }
                    }
                    HStack {
                        SecureField(S.tokenPlaceholder, text: $token).textFieldStyle(.roundedBorder)
                        Button(S.connect) {
                            let value = extract(token)
                            Task { await store.signIn(sessionToken: value) }
                        }
                        .disabled(token.isEmpty || store.loading)
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 460)
            .font(.callout)
            Text(S.unofficialNote)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Accepts either the bare token or the whole JSON the page shows.
    private func extract(_ input: String) -> String {
        if let range = input.range(of: #"[A-Za-z0-9]{64}"#, options: .regularExpression) {
            return String(input[range])
        }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension TrophyRarity {
    var label: String {
        switch self {
        case .ultraRare: return S.ultraRare
        case .veryRare: return S.veryRare
        case .rare: return S.rare
        case .common: return S.common
        }
    }

    var color: Color {
        switch self {
        case .ultraRare: return .orange
        case .veryRare: return .purple
        case .rare: return .blue
        case .common: return .gray
        }
    }
}
