import Foundation
import Testing
@testable import RemoteLove

@MainActor
struct RemoteLoveTests {
    @Test func `Demo contains separate care profiles`() {
        #expect(DemoFixtures.recipients.count == 2)
        #expect(DemoFixtures.mumID != DemoFixtures.dadID)
    }

    @Test func `Medicine supply drops when a linked task completes`() throws {
        let store = RemoteLoveStore()
        let existingTask = try #require(
            store.tasks.first(where: { $0.medicineID == DemoFixtures.amlodipineID })
        )
        let before = try #require(
            store.medicines.first(where: { $0.id == DemoFixtures.amlodipineID })?.currentSupply
        )
        var task = existingTask
        task.id = UUID()
        task.state = .pending
        store.tasks.append(task)
        store.setTask(task.id, state: .done)
        let after = store.medicines.first(where: { $0.id == DemoFixtures.amlodipineID })?.currentSupply
        #expect(after == before - 1)
    }

    @Test func `Demo helper invitation selects the correct profile and route`() {
        let store = RemoteLoveStore()
        #expect(store.joinAsHelper(name: "Ana", code: "CARE4726"))
        #expect(store.selectedRecipientID == DemoFixtures.dadID)
        #expect(store.currentRole == .helper)
        #expect(store.route == .helperApp)
    }

    @Test func `New family care setup is an explicit route`() {
        let store = RemoteLoveStore()
        #expect(store.route == .welcome)

        store.beginNewCareSetup()

        #expect(store.route == .createCareSetup)
        #expect(store.recipients == DemoFixtures.recipients)
    }

    @Test func `Password policy requires all standard criteria`() {
        #expect(PasswordPolicy.isValid("Strong1!"))
        #expect(!PasswordPolicy.isValid("Short1!"))
        #expect(!PasswordPolicy.isValid("lowercase1!"))
        #expect(!PasswordPolicy.isValid("UPPERCASE1!"))
        #expect(!PasswordPolicy.isValid("NoNumber!"))
        #expect(!PasswordPolicy.isValid("NoSpecial1"))
    }

    @Test func `Tasks for overview only include the requested profile and date`() throws {
        let store = RemoteLoveStore()
        let recipient = try #require(store.recipients.first)
        let anotherRecipient = try #require(store.recipients.dropFirst().first)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))

        store.tasks = [
            CareTask(id: UUID(), recipientID: recipient.id, title: "Today", instructions: "", scheduledAt: today, frequency: "Does not repeat", requiresPhoto: false, state: .done, notifiedAt: nil, medicineID: nil),
            CareTask(id: UUID(), recipientID: recipient.id, title: "Tomorrow", instructions: "", scheduledAt: tomorrow, frequency: "Does not repeat", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil),
            CareTask(id: UUID(), recipientID: anotherRecipient.id, title: "Other profile", instructions: "", scheduledAt: today, frequency: "Does not repeat", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil)
        ]

        let overviewTasks = store.tasks(on: today, recipientID: recipient.id)

        #expect(overviewTasks.map(\.title) == ["Today"])
        #expect(overviewTasks.allSatisfy { $0.state == .done })
    }
}
