import SwiftUI

// MARK: - Ana menü özet şeridi

struct ProgressStrip: View {
    let summary: ProgressSummary?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.15))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("İlerleme")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.accentBrown, .accentBrownDark],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        guard let s = summary, s.testsTaken > 0 else {
            return "Henüz test yok — Kelime Testi'ni dene"
        }
        let avg = Int((s.avgAccuracy * 100).rounded())
        var parts = ["\(s.testsTaken) test", "Ort. %\(avg)"]
        if let lc = s.lastCorrect, let lt = s.lastTotal, lt > 0 {
            parts.append("Son: \(lc)/\(lt)")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - İlerleme detay ekranı

struct ProgressDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summary: ProgressSummary?
    @State private var categories: [CategoryProgress] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let s = summary, s.testsTaken > 0 {
                        statRow(s)
                        section("Test geçmişi") {
                            VStack(spacing: 0) {
                                ForEach(Array(s.recent.enumerated()), id: \.offset) { idx, r in
                                    if idx > 0 { Divider() }
                                    HStack {
                                        Text(dateString(r.takenAt))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(r.correct)/\(r.total)")
                                            .font(.subheadline.weight(.semibold))
                                        Text("%\(pct(r.correct, r.total))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 48, alignment: .trailing)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if !isLoading {
                        Text("Henüz test yapmadın. Ana menüden Kelime Testi'ni deneyerek ilerlemeni burada gör.")
                            .foregroundStyle(.secondary)
                    }

                    if !categories.isEmpty {
                        section("Kategorilere göre öğrenilen kelimeler") {
                            VStack(spacing: 14) {
                                ForEach(categories) { c in
                                    categoryRow(c)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("İlerleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        summary = try? await APIService.progressSummary()
        categories = (try? await APIService.learnedByCategory())?.categories ?? []
        isLoading = false
    }

    private func statRow(_ s: ProgressSummary) -> some View {
        HStack(spacing: 12) {
            stat("Test", "\(s.testsTaken)")
            stat("Ortalama", "%\(Int((s.avgAccuracy * 100).rounded()))")
            if let lc = s.lastCorrect, let lt = s.lastTotal, lt > 0 {
                stat("Son", "%\(pct(lc, lt))")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
    }

    private func categoryRow(_ c: CategoryProgress) -> some View {
        let ratio: Double = c.total > 0 ? min(1, Double(c.learned) / Double(c.total)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(c.label).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(c.learned) / \(c.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 8)
                    Capsule().fill(Color.blue).frame(width: geo.size.width * ratio, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func pct(_ correct: Int, _ total: Int) -> Int {
        total > 0 ? Int((Double(correct) / Double(total) * 100).rounded()) : 0
    }

    private func dateString(_ iso: String) -> String {
        // "2026-07-10T12:34:56..." → "2026-07-10"
        String(iso.prefix(10))
    }
}
