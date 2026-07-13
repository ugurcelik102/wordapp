import SwiftUI
import Combine

@MainActor
final class PlacementViewModel: ObservableObject {
    @Published var test: PlacementTestResponse?
    @Published var answers: [Int: String] = [:]          // question_id → selected_option
    @Published var result: PlacementResult?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var currentIndex = 0

    var currentQuestion: PlacementQuestion? {
        guard let questions = test?.questions, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard let total = test?.questions.count, total > 0 else { return 0 }
        return Double(currentIndex) / Double(total)
    }

    var isLastQuestion: Bool {
        guard let total = test?.questions.count else { return false }
        return currentIndex == total - 1
    }

    var allAnswered: Bool {
        guard let total = test?.questions.count else { return false }
        return answers.count == total
    }

    func loadTest() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            test = try await APIService.getPlacementTest()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAnswer(_ option: String) {
        guard let q = currentQuestion else { return }
        answers[q.questionId] = option

        // Kısa gecikme sonrası sonraki soruya geç
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !self.isLastQuestion {
                withAnimation { self.currentIndex += 1 }
            }
        }
    }

    func submit() async {
        guard let test else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let questionAnswers = answers.map { QuestionAnswer(questionId: $0.key, selectedOption: $0.value) }

        do {
            result = try await APIService.submitPlacement(testId: test.testId, answers: questionAnswers)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLevel(levelId: Int, appState: AppState) async {
        guard let result else { return }
        do {
            _ = try await APIService.updateLevel(resultId: result.resultId, levelId: levelId)
            appState.didCompletePlacement(levelId: levelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
