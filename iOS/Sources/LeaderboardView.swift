import SwiftUI

struct LeaderboardView: View {
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
            Button(M.openPSNProfiles, systemImage: "safari") {
                Task {
                    var name = board.latest.flatMap { s in s.rows.first { $0.player.id == s.me } }?.player.onlineId
                    if name == nil { name = try? await PSNClient.shared.me().onlineId }
                    guard let id = name, let url = URL(string: "https://psnprofiles.com/\(id)") else { return }
                    await UIApplication.shared.open(url)
                }
            }
        } footer: {
            Text(M.psnProfilesHint)
        }
    }

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
