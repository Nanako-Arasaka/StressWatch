import Foundation

@MainActor
class TrendViewModel: ObservableObject {
    @Published var stressHistory: [StressScore]
    @Published var isLoading: Bool

    private let storage: any LocalStorageProtocol
    private let calendar: Calendar

    init(storage: any LocalStorageProtocol, calendar: Calendar = .current) {
        self.storage = storage
        self.calendar = calendar
        self.stressHistory = []
        self.isLoading = false
    }

    func loadHistory(days: Int) async {
        isLoading = true

        do {
            let now = Date()
            let endDate = calendar.endOfDay(for: now)
            let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
            stressHistory = try storage.fetchStressScores(from: startDate, to: endDate)
            isLoading = false
        } catch {
            stressHistory = []
            isLoading = false
        }
    }
}
