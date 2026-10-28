import SwiftUI

struct TargetsView: View {
    private var targets: TrophyTargets { .shared }
    private var store: TrophyStore { .shared }

    var body: some View {
        NavigationStack {
            List {
                ForEach(targets.sorted) { target in
                    let game = store.games.first { $0.id == target.gameID }
                    NavigationLink(value: game) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(target.trophyName).font(.subheadline.weight(.medium))
                            Text(target.gameName).font(.caption).foregroundStyle(.secondary)
                            if !target.note.isEmpty {
                                Text(target.note).font(.caption).foregroundStyle(.tint).lineLimit(3)
                            }
                        }
                    }
                    .disabled(game == nil)
                }
                .onDelete { offsets in
                    let list = targets.sorted
                    offsets.forEach { targets.remove(list[$0]) }
                }
            }
            .overlay {
                if targets.sorted.isEmpty {
                    ContentUnavailableView(S.noTargets, systemImage: "pin", description: Text(S.noTargetsHint))
                }
            }
            .screen(M.targetsTab)
            .navigationDestination(for: TrophyGame?.self) { game in
                if let game { GameView(game: game) }
            }
        }
    }
}
