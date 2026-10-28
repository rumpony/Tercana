import SafariServices
import SwiftUI

struct LeaderboardView: View {
    @State private var showingWeb: URL?
    /// Picked once, kept for good (Turkey unless changed).
    @AppStorage("leaderboardCountry") private var country = "tr"
    private var board: Leaderboard { .shared }

    var body: some View {
        Group {
            if let latest = board.latest {
                summary(latest)
                ForEach(Array(latest.rows.enumerated()), id: \.element.id) { index, row in
                    NavigationLink(value: row.player) { rowView(index + 1, row, isMe: row.player.id == latest.me) }
                        .listRowBackground(row.player.id == latest.me ? Style.glow.opacity(0.18) : nil)
                }
            }
            Section {
                Button {
                    Task { await board.refresh() }
                } label: {
                    if board.refreshing {
                        HStack { ProgressView(); Text(M.refreshing(board.done, board.total)) }
                    } else {
                        Label(M.refreshLeaderboard, systemImage: "arrow.clockwise")
                    }
                }
                .disabled(board.refreshing)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let date = board.latest?.date { Text(M.updatedAt(date.shown(time: true))) }
                    Text(M.leaderboardHint)
                }
            }
        }
        Section {
            Picker(M.country, selection: $country) {
                ForEach(Self.countries, id: \.code) { Text($0.name).tag($0.code) }
            }
            Button(M.countryBoard(Self.name(country)), systemImage: "flag") {
                showingWeb = URL(string: "https://psnprofiles.com/leaderboard/all/\(country)")
            }
            if let me = board.latest.flatMap({ s in s.rows.first { $0.player.id == s.me } }) {
                Button(M.myCountryRank, systemImage: "person.crop.circle.badge.questionmark") {
                    showingWeb = URL(string: "https://psnprofiles.com/\(me.player.onlineId)")
                }
            }
        } header: {
            Text("PSNProfiles")
        } footer: {
            Text(M.psnProfilesHint)
        }
        .sheet(item: $showingWeb) { SafariView(url: $0).ignoresSafeArea() }
    }

    private static func name(_ code: String) -> String {
        S.locale.localizedString(forRegionCode: code.uppercased()) ?? code.uppercased()
    }

    private static let countries: [(code: String, name: String)] = Locale.Region.isoRegions
        .filter { $0.identifier.count == 2 && $0.identifier.allSatisfy(\.isLetter) }
        .map { (code: $0.identifier.lowercased(), name: name($0.identifier)) }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

    private func summary(_ latest: Leaderboard.Snapshot) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                if let rank = latest.myRank {
                    Text(M.yourRank(rank, latest.rows.count)).font(.title3.bold())
                }
                HStack {
                    move(M.today, from: board.startOfToday, to: latest)
                    move(M.sinceYesterday, from: board.yesterday, to: latest)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func move(_ title: String, from old: Leaderboard.Snapshot?, to new: Leaderboard.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let old, let oldRank = old.myRank, let newRank = new.myRank,
               let oldPoints = old.myPoints, let newPoints = new.myPoints {
                Text("\(M.rankMove(oldRank - newRank)) · \(M.pointsMove(newPoints - oldPoints)) \(M.points.lowercased())")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(newPoints > oldPoints ? Style.glow : .primary)
            } else {
                Text("–").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowView(_ rank: Int, _ row: Leaderboard.Row, isMe: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.headline.monospacedDigit()).frame(width: 30)
                .foregroundStyle(rank <= 3 ? [TrophyGrade.gold, .silver, .bronze][rank - 1].color : .secondary)
            AsyncImage(url: row.player.avatarURL) { $0.resizable() } placeholder: { Color.secondary.opacity(0.15) }
                .frame(width: 36, height: 36).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(row.player.onlineId).font(.subheadline.weight(isMe ? .bold : .medium)).lineLimit(1)
                Text("\(M.level) \(row.level) · 🏆 \(row.counts.platinum)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(row.points.formatted()).font(.subheadline.monospacedDigit())
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
