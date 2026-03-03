import XCTest
@testable import Helpy

final class AssistantFeatureTests: XCTestCase {
    func testActionNormalizerFiltersInvalidActionsAndMapsPriorityAndDates() {
        let batch = ParsedAssistantActionBatch(actions: [
            ParsedAssistantAction(action: "create", targetId: nil, targetTitle: nil, title: " Send invoice ", dueDate: "2026-03-04", dueTime: nil, priority: "high", newPosition: nil, completed: nil, scheduleFieldsWereProvided: true),
            ParsedAssistantAction(action: "delete", targetId: nil, targetTitle: "Missing", title: nil, dueDate: nil, dueTime: nil, priority: nil, newPosition: nil, completed: nil),
            ParsedAssistantAction(action: "reorder", targetId: "task-2", targetTitle: "Plan launch post", title: nil, dueDate: nil, dueTime: nil, priority: nil, newPosition: 1, completed: nil)
        ])

        let normalized = AssistantActionNormalizer.normalize(batch: batch, sourceText: "source", reminders: [], maxActions: 5)

        XCTAssertEqual(normalized.sourceText, "source")
        XCTAssertEqual(normalized.actions.count, 2)
        XCTAssertEqual(normalized.actions[0].kind, .create)
        XCTAssertEqual(normalized.actions[0].title, "Send invoice")
        XCTAssertEqual(normalized.actions[0].priority, 1)
        XCTAssertNotNil(normalized.actions[0].schedule?.date)
        XCTAssertFalse(normalized.actions[0].schedule?.hasTime ?? true)
        XCTAssertEqual(normalized.actions[1].kind, .reorder)
        XCTAssertEqual(normalized.actions[1].targetReminderId, "task-2")
        XCTAssertEqual(normalized.actions[1].newPosition, 1)
    }

    func testActionNormalizerRepairsMislabelledCreateIntoUpdateWhenExistingTargetMatches() {
        let reminders = [AssistantReminderContext(id: "r2", title: "Call Alex", dueDate: nil, priority: 0, isCompleted: false, position: 2)]
        let batch = ParsedAssistantActionBatch(actions: [
            ParsedAssistantAction(action: "create", targetId: "r2", targetTitle: "Call Alex", title: "Call Alex about the launch", dueDate: nil, dueTime: nil, priority: nil, newPosition: nil, completed: nil)
        ])

        let normalized = AssistantActionNormalizer.normalize(batch: batch, sourceText: "Rename Call Alex", reminders: reminders, maxActions: 5)

        XCTAssertEqual(normalized.actions.count, 1)
        XCTAssertEqual(normalized.actions[0].kind, .update)
        XCTAssertEqual(normalized.actions[0].targetReminderId, "r2")
    }

    func testPriorityMapperDefaultsUnknownValuesToNone() {
        XCTAssertEqual(AssistantPriorityMapper.normalize("high"), 1)
        XCTAssertEqual(AssistantPriorityMapper.normalize("medium"), 5)
        XCTAssertEqual(AssistantPriorityMapper.normalize("low"), 9)
        XCTAssertEqual(AssistantPriorityMapper.normalize("unknown"), 0)
        XCTAssertEqual(AssistantPriorityMapper.normalize(nil), 0)
    }

    func testActionNormalizerPreservesDateOnlyScheduleWithoutTime() {
        let batch = ParsedAssistantActionBatch(actions: [
            ParsedAssistantAction(action: "create", targetId: nil, targetTitle: nil, title: "Gym", dueDate: "2026-03-03", dueTime: nil, priority: nil, newPosition: nil, completed: nil, scheduleFieldsWereProvided: true)
        ])

        let normalized = AssistantActionNormalizer.normalize(batch: batch, sourceText: "today gym", reminders: [], maxActions: 5)

        XCTAssertEqual(normalized.actions.count, 1)
        XCTAssertNotNil(normalized.actions[0].schedule?.date)
        XCTAssertNil(normalized.actions[0].schedule?.time)
    }

    func testActionNormalizerDropsTimeWithoutDate() {
        let batch = ParsedAssistantActionBatch(actions: [
            ParsedAssistantAction(action: "create", targetId: nil, targetTitle: nil, title: "Gym", dueDate: nil, dueTime: "18:00", priority: nil, newPosition: nil, completed: nil, scheduleFieldsWereProvided: true)
        ])

        let normalized = AssistantActionNormalizer.normalize(batch: batch, sourceText: "go to the gym at 18:00", reminders: [], maxActions: 5)

        XCTAssertEqual(normalized.actions.count, 1)
        XCTAssertEqual(normalized.actions[0].schedule, .empty)
    }

    func testSettingsValidatorRequiresInputPlaceholder() {
        XCTAssertNil(AssistantSettingsValidator.validateTranscription(command: "/usr/bin/whisper", argsTemplate: "--file {input}"))
        XCTAssertEqual(
            AssistantSettingsValidator.validateTranscription(command: "/usr/bin/whisper", argsTemplate: "--file foo"),
            "Transcription args must include {input}."
        )
    }

    func testSettingsValidatorRejectsEmptyOllamaValues() {
        XCTAssertEqual(
            AssistantSettingsValidator.validateOllama(baseURL: "", model: "qwen3.5:0.8b"),
            "Ollama base URL cannot be empty."
        )
        XCTAssertEqual(
            AssistantSettingsValidator.validateOllama(baseURL: "http://127.0.0.1:11434", model: ""),
            "Ollama model cannot be empty."
        )
    }

    func testWhisperProviderReportsMissingCommand() async {
        let provider = WhisperCLITranscriptionProvider(command: "/definitely/missing/whisper", argsTemplate: "--file {input} --model {model}", modelPath: "/tmp/model.bin")

        do {
            _ = try await provider.transcribe(audioFileURL: URL(fileURLWithPath: "/tmp/audio.m4a"))
            XCTFail("Expected missing command to throw.")
        } catch let error as AssistantError {
            XCTAssertEqual(error, .transcriptionCommandNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

@MainActor
final class AssistantCoordinatorTests: XCTestCase {
    func testUpdateActionMutatesActionInsideReviewState() {
        let coordinator = AssistantCoordinator()
        let originalAction = AssistantActionDraft(kind: .create, title: "Original", schedule: .empty, priority: 0)
        coordinator.state = .review(AssistantSuggestionBatch(sourceText: "hello", actions: [originalAction]))

        var updatedAction = originalAction
        updatedAction.title = "Updated"
        updatedAction.priority = 1
        coordinator.updateAction(updatedAction)

        guard case .review(let batch) = coordinator.state else {
            return XCTFail("Expected review state.")
        }

        XCTAssertEqual(batch.actions.first?.title, "Updated")
        XCTAssertEqual(batch.actions.first?.priority, 1)
    }

    func testDiscardAllActionsReturnsCoordinatorToIdle() {
        let coordinator = AssistantCoordinator()
        coordinator.state = .review(AssistantSuggestionBatch(sourceText: "hello", actions: [AssistantActionDraft(kind: .create, title: "One")]))

        coordinator.discardAllActions()

        XCTAssertEqual(coordinator.state, .idle)
    }
}
