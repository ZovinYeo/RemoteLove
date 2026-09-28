//
//  RemoteLoveWidgets.swift
//  RemoteLoveWidgets
//
//  Created by Zovin Yeo on 22/9/26.
//

import SwiftUI
import WidgetKit
import AppIntents

private let remoteLoveWidgetKind = "RemoteLoveWidgets"
private let remoteLoveAppGroupID = "group.com.zozo.remotelove"
private let remoteLoveWidgetSnapshotKey = "RemoteLove.widget.snapshot"
private let remoteLoveWidgetQueuedActionsKey = "RemoteLove.widget.queuedActions"

private struct RemoteLoveWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var recipientName: String
    var recipientLabel: String
    var roleName: String
    var completedTaskCount: Int
    var totalTaskCount: Int
    var nextTaskID: UUID?
    var nextTaskRecipientID: UUID?
    var nextTaskTitle: String?
    var nextTaskTime: Date?
    var nextTaskRequiresPhoto: Bool
    var medicineAttentionCount: Int
    var healthAttentionCount: Int
}

private struct RemoteLoveWidgetQueuedAction: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case completeTask
    }

    var id: UUID
    var kind: Kind
    var taskID: UUID
    var recipientID: UUID
    var scheduledAt: Date
    var createdAt: Date
}

struct CompleteRemoteLoveWidgetTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark RemoteLove Task Done"
    static var description = IntentDescription("Marks the next RemoteLove care task as done.")

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: remoteLoveAppGroupID),
              let data = defaults.data(forKey: remoteLoveWidgetSnapshotKey),
              var snapshot = try? JSONDecoder().decode(RemoteLoveWidgetSnapshot.self, from: data),
              let taskID = snapshot.nextTaskID,
              let recipientID = snapshot.nextTaskRecipientID,
              let scheduledAt = snapshot.nextTaskTime,
              snapshot.nextTaskRequiresPhoto == false else {
            return .result()
        }

        let action = RemoteLoveWidgetQueuedAction(
            id: UUID(),
            kind: .completeTask,
            taskID: taskID,
            recipientID: recipientID,
            scheduledAt: scheduledAt,
            createdAt: Date()
        )

        var actions: [RemoteLoveWidgetQueuedAction] = []
        if let actionData = defaults.data(forKey: remoteLoveWidgetQueuedActionsKey),
           let decoded = try? JSONDecoder().decode([RemoteLoveWidgetQueuedAction].self, from: actionData) {
            actions = decoded
        }
        actions.append(action)
        if let encodedActions = try? JSONEncoder().encode(actions) {
            defaults.set(encodedActions, forKey: remoteLoveWidgetQueuedActionsKey)
        }

        snapshot.completedTaskCount = min(snapshot.completedTaskCount + 1, snapshot.totalTaskCount)
        snapshot.nextTaskID = nil
        snapshot.nextTaskRecipientID = nil
        snapshot.nextTaskTitle = snapshot.completedTaskCount >= snapshot.totalTaskCount ? nil : "Open RemoteLove for the next task"
        snapshot.nextTaskTime = nil
        snapshot.nextTaskRequiresPhoto = false
        snapshot.updatedAt = Date()
        if let encodedSnapshot = try? JSONEncoder().encode(snapshot) {
            defaults.set(encodedSnapshot, forKey: remoteLoveWidgetSnapshotKey)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: remoteLoveWidgetKind)
        return .result()
    }
}

private struct RemoteLoveWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: RemoteLoveWidgetSnapshot
}

private struct RemoteLoveWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteLoveWidgetEntry {
        RemoteLoveWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RemoteLoveWidgetEntry) -> Void) {
        completion(RemoteLoveWidgetEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteLoveWidgetEntry>) -> Void) {
        let entry = RemoteLoveWidgetEntry(date: Date(), snapshot: loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> RemoteLoveWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: remoteLoveAppGroupID),
              let data = defaults.data(forKey: remoteLoveWidgetSnapshotKey),
              let snapshot = try? JSONDecoder().decode(RemoteLoveWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

private struct RemoteLoveWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RemoteLoveWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            case .accessoryCircular:
                circularWidget
            case .accessoryRectangular:
                rectangularWidget
            default:
                smallWidget
            }
        }
        .containerBackground(RemoteLoveWidgetTheme.background, for: .widget)
        .foregroundStyle(RemoteLoveWidgetTheme.text)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(RemoteLoveWidgetTheme.coral)
                Spacer()
                Text(progressText)
                    .font(.caption.bold())
                    .foregroundStyle(RemoteLoveWidgetTheme.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RemoteLoveWidgetTheme.greenSoft, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.snapshot.recipientLabel)
                    .font(.headline)
                    .foregroundStyle(RemoteLoveWidgetTheme.text)
                    .lineLimit(1)
                Text(nextTaskText)
                    .font(.caption)
                    .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
                    .lineLimit(2)
            }

            ProgressView(value: progress)
                .tint(RemoteLoveWidgetTheme.green)

            doneButton

            attentionFooter
        }
        .padding()
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(RemoteLoveWidgetTheme.green.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(RemoteLoveWidgetTheme.green, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(progressText)
                        .font(.headline.bold())
                        .foregroundStyle(RemoteLoveWidgetTheme.text)
                    Text("done")
                        .font(.caption2)
                        .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.snapshot.recipientName)
                    .font(.headline)
                    .foregroundStyle(RemoteLoveWidgetTheme.text)
                    .lineLimit(1)
                Label(nextTaskText, systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    statusPill(
                        title: "\(entry.snapshot.medicineAttentionCount)",
                        icon: "pills.fill",
                        color: RemoteLoveWidgetTheme.amber
                    )
                    statusPill(
                        title: "\(entry.snapshot.healthAttentionCount)",
                        icon: "heart.text.square.fill",
                        color: RemoteLoveWidgetTheme.coral
                    )
                    doneButton
                }
                Text("Updated \(entry.snapshot.updatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: progress >= 1 && entry.snapshot.totalTaskCount > 0 ? "checkmark" : "heart.fill")
                    .font(.caption.bold())
                Text(progressText)
                    .font(.caption2.bold())
            }
            .foregroundStyle(RemoteLoveWidgetTheme.green)
        }
    }

    private var rectangularWidget: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                Text(entry.snapshot.recipientLabel)
                    .lineLimit(1)
            }
            .font(.caption.bold())
            Text(nextTaskText)
                .font(.caption2)
                .lineLimit(1)
            Text("\(progressText) tasks complete")
                .font(.caption2)
                .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
        }
    }

    private var attentionFooter: some View {
        HStack(spacing: 8) {
            Label("\(entry.snapshot.medicineAttentionCount)", systemImage: "pills.fill")
            Label("\(entry.snapshot.healthAttentionCount)", systemImage: "heart.text.square.fill")
        }
        .font(.caption2.bold())
        .foregroundStyle(RemoteLoveWidgetTheme.secondaryText)
    }

    @ViewBuilder
    private var doneButton: some View {
        if entry.snapshot.nextTaskID != nil && entry.snapshot.nextTaskRequiresPhoto == false {
            Button(intent: CompleteRemoteLoveWidgetTaskIntent()) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(RemoteLoveWidgetTheme.green)
            .invalidatableContent()
        } else if entry.snapshot.nextTaskRequiresPhoto {
            Label("Photo needed", systemImage: "camera.fill")
                .font(.caption.bold())
                .foregroundStyle(RemoteLoveWidgetTheme.coral)
        }
    }

    private var progress: Double {
        guard entry.snapshot.totalTaskCount > 0 else { return 0 }
        return Double(entry.snapshot.completedTaskCount) / Double(entry.snapshot.totalTaskCount)
    }

    private var progressText: String {
        "\(entry.snapshot.completedTaskCount)/\(entry.snapshot.totalTaskCount)"
    }

    private var nextTaskText: String {
        guard let title = entry.snapshot.nextTaskTitle, title.isEmpty == false else {
            return entry.snapshot.totalTaskCount == 0 ? "No tasks planned today" : "All tasks completed"
        }

        if let nextTaskTime = entry.snapshot.nextTaskTime {
            return "\(nextTaskTime.formatted(date: .omitted, time: .shortened)) · \(title)"
        }

        return title
    }

    private func statusPill(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct RemoteLoveWidgets: Widget {
    let kind: String = remoteLoveWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemoteLoveWidgetProvider()) { entry in
            RemoteLoveWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("RemoteLove Care")
        .description("See today’s care progress, next task and attention items at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private enum RemoteLoveWidgetTheme {
    static let green = Color(red: 0.08, green: 0.40, blue: 0.33)
    static let greenSoft = Color(red: 0.82, green: 0.92, blue: 0.86)
    static let coral = Color(red: 0.88, green: 0.22, blue: 0.24)
    static let amber = Color(red: 0.74, green: 0.42, blue: 0.06)
    static let background = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let text = Color(red: 0.10, green: 0.13, blue: 0.12)
    static let secondaryText = Color(red: 0.34, green: 0.40, blue: 0.37)
}

private extension RemoteLoveWidgetSnapshot {
    static let placeholder = RemoteLoveWidgetSnapshot(
        updatedAt: Date(),
        recipientName: "Mum",
        recipientLabel: "Mum",
        roleName: "Family",
        completedTaskCount: 3,
        totalTaskCount: 5,
        nextTaskID: UUID(),
        nextTaskRecipientID: UUID(),
        nextTaskTitle: "Lunch medicine",
        nextTaskTime: Date().addingTimeInterval(3_600),
        nextTaskRequiresPhoto: false,
        medicineAttentionCount: 1,
        healthAttentionCount: 0
    )

    static let empty = RemoteLoveWidgetSnapshot(
        updatedAt: Date(),
        recipientName: "RemoteLove",
        recipientLabel: "Care",
        roleName: "Family",
        completedTaskCount: 0,
        totalTaskCount: 0,
        nextTaskID: nil,
        nextTaskRecipientID: nil,
        nextTaskTitle: "Open RemoteLove to update widgets",
        nextTaskTime: nil,
        nextTaskRequiresPhoto: false,
        medicineAttentionCount: 0,
        healthAttentionCount: 0
    )
}
