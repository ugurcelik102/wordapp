import SwiftUI

struct ReadingTopic: Identifiable {
    let id = UUID()
    let label: String       // ekranda gösterilen Türkçe etiket
    let scenario: String    // backend'e gönderilen İngilizce senaryo
    let icon: String
}

struct ReadingOptionsView: View {
    let onLearned: () -> Void
    let onTopic: (_ scenario: String, _ asDialogue: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var asDialogue = true

    private let topics: [ReadingTopic] = [
        .init(label: "Adres sorma",      scenario: "asking for and giving directions in a city",   icon: "map"),
        .init(label: "Havaalanında",     scenario: "at the airport: check-in, security and boarding", icon: "airplane"),
        .init(label: "Otel resepsiyonu", scenario: "hotel reception check-in and guest requests",    icon: "bell"),
        .init(label: "Restoranda",       scenario: "ordering food and drinks at a restaurant",       icon: "fork.knife"),
        .init(label: "Alışveriş",        scenario: "shopping for clothes in a store",                icon: "bag"),
        .init(label: "Doktorda",         scenario: "a doctor visit describing symptoms",             icon: "cross.case"),
        .init(label: "Toplu taşıma",     scenario: "buying a ticket and using public transport",     icon: "bus"),
        .init(label: "Telefon görüşmesi", scenario: "a phone call to make an appointment",           icon: "phone"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Seçenek 1: öğrenilen kelimelerden
                    Button {
                        dismiss()
                        onLearned()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Color(red: 0.22, green: 0.74, blue: 0.28))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Öğrenilen kelimelerden")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Çalıştığın kelimelerle bir metin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // Seçenek 2: konu seç
                    HStack {
                        Text("veya bir konu seç")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle(isOn: $asDialogue) {
                            Text("Diyalog")
                                .font(.subheadline)
                        }
                        .fixedSize()
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(topics) { topic in
                            Button {
                                dismiss()
                                onTopic(topic.scenario, asDialogue)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: topic.icon)
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                    Text(topic.label)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Okuma Parçası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
