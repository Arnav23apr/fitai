import SwiftUI

@Observable
class CoachViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let aiService = AIService()

    func buildSystemContext(profile: UserProfile) -> String {
        var context = """
        You are Fit AI Coach, a premium personal fitness and nutrition coach inside the Fit AI app.
        Be concise, motivating, and knowledgeable. Use a friendly but professional tone.
        Keep responses focused and actionable — no walls of text.
        Format key points with bullet points when listing things.
        You can help with workout advice, nutrition, form tips, recovery, motivation, and general fitness questions.
        """

        if !profile.primaryGoal.isEmpty {
            context += "\nUser's primary goal: \(profile.primaryGoal)"
        }
        if !profile.trainingExperience.isEmpty {
            context += "\nTraining experience: \(profile.trainingExperience)"
        }
        if !profile.trainingLocation.isEmpty {
            context += "\nTrains at: \(profile.trainingLocation)"
        }
        context += "\nWorkouts per week: \(profile.workoutsPerWeek)"
        context += "\nTraining confidence: \(profile.trainingConfidence)/10"

        if let score = profile.latestScore {
            context += "\nLatest physique score: \(String(format: "%.1f", score))/10"
        }
        if !profile.weakPoints.isEmpty {
            context += "\nWeak points to improve: \(profile.weakPoints.joined(separator: ", "))"
        }
        if !profile.strongPoints.isEmpty {
            context += "\nStrong points: \(profile.strongPoints.joined(separator: ", "))"
        }
        if !profile.holdingBack.isEmpty {
            context += "\nChallenges: \(profile.holdingBack.joined(separator: ", "))"
        }
        if !profile.goals.isEmpty {
            context += "\n90-day goals: \(profile.goals.joined(separator: ", "))"
        }

        let heightFt = Int(profile.heightCm / 30.48)
        let heightIn = Int((profile.heightCm / 2.54).truncatingRemainder(dividingBy: 12))
        let weightLbs = Int(profile.weightKg * 2.205)
        context += "\nHeight: \(heightFt)'\(heightIn)\" (\(Int(profile.heightCm))cm)"
        context += "\nWeight: \(weightLbs)lbs (\(Int(profile.weightKg))kg)"

        if !profile.gender.isEmpty {
            context += "\nGender: \(profile.gender)"
        }

        return context
    }

    func sendMessage(profile: UserProfile) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let systemContext = buildSystemContext(profile: profile)
                var apiMessages: [ChatAPIMessage] = [
                    ChatAPIMessage(role: "system", text: systemContext)
                ]
                for msg in messages {
                    apiMessages.append(ChatAPIMessage(role: msg.role.rawValue, text: msg.content))
                }

                let response = try await aiService.chat(messages: apiMessages)
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func sendQuickQuestion(_ question: String, profile: UserProfile) {
        inputText = question
        sendMessage(profile: profile)
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}
