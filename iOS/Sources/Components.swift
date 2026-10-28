import SwiftUI

extension TrophyGrade {
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.27)
        case .silver: return Color(red: 0.62, green: 0.66, blue: 0.72)
        case .gold: return Color(red: 0.95, green: 0.74, blue: 0.20)
        case .platinum: return Color(red: 0.55, green: 0.72, blue: 0.95)
        }
    }
}

extension TrophyRarity {
    var title: String {
        switch self {
        case .ultraRare: return S.ultraRare
        case .veryRare: return S.veryRare
        case .rare: return S.rare
        case .common: return S.common
        }
    }
}

/// Game or trophy artwork with a quiet placeholder.
struct Artwork: View {
    let url: URL?
    var size: CGFloat = 48

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.secondary.opacity(0.15)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}

/// Trophy counts as four colored dots with numbers.
struct GradeCounts: View {
    let counts: TrophyCounts
    var defined: TrophyCounts?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TrophyGrade.allCases, id: \.self) { grade in
                let value = counts.value(grade)
                if let defined, defined.value(grade) == 0 {
                    EmptyView()
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(grade.color).frame(width: 8, height: 8)
                        Text(defined.map { "\(value)/\($0.value(grade))" } ?? "\(value)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension TrophyCounts {
    func value(_ grade: TrophyGrade) -> Int {
        switch grade {
        case .bronze: return bronze
        case .silver: return silver
        case .gold: return gold
        case .platinum: return platinum
        }
    }
}

/// One number with a caption, used in small grids.
struct Figure: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
