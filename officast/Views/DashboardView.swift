//
//  DashboardView.swift
//  officast
//
//  Today's + tomorrow's recommendation and this month's progress (SPEC §6.2).
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var model = DashboardModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("dashboard.title")
                .task { await refresh() }
                .refreshable { await refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("dashboard.loading")
        case .failed(let message):
            ContentUnavailableView {
                Label("dashboard.errorTitle", systemImage: "cloud.slash")
            } description: {
                Text(message)
            } actions: {
                Button("common.retry") { Task { await refresh() } }
            }
        case .loaded(let data):
            loaded(data)
        }
    }

    private func loaded(_ data: DashboardModel.Data) -> some View {
        List {
            if data.offline {
                Label("dashboard.offline", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
            }

            Section("dashboard.progress") {
                LabeledContent("dashboard.officeDone",
                               value: "\(data.officeDone) / \(data.requiredOfficeDays)")
                LabeledContent("dashboard.remaining", value: "\(data.remainingWorkdays)")
                LabeledContent("dashboard.slack", value: "\(data.slack)")
                if data.slack < 0 {
                    Label("dashboard.slackWarning", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("dashboard.today") {
                recommendationRow(data.today, showFlags: true, interpolated: data.todayInterpolated,
                                  hasForecast: data.hasTodayForecast)
            }

            if let tomorrow = data.tomorrow {
                Section("dashboard.tomorrow") {
                    recommendationRow(tomorrow, showFlags: false, interpolated: false, hasForecast: true)
                }
            }
        }
    }

    @ViewBuilder
    private func recommendationRow(
        _ result: DecisionResult, showFlags: Bool, interpolated: Bool, hasForecast: Bool
    ) -> some View {
        if !hasForecast {
            Label("dashboard.noForecast", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon(for: result))
                        .foregroundStyle(tint(for: result))
                    Text(RecommendationPresentation.headline(result))
                        .font(.headline)
                }
                Text(RecommendationPresentation.reason(result))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if showFlags && RecommendationPresentation.isHalfDay(result) {
                    Label("dashboard.halfDayTip", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if showFlags && interpolated {
                    Label("dashboard.interpolated", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func icon(for result: DecisionResult) -> String {
        switch result.recommendation {
        case .office: return "building.2.fill"
        case .wfh: return "house.fill"
        }
    }

    private func tint(for result: DecisionResult) -> Color {
        switch result.recommendation {
        case .office: return .green
        case .wfh: return .blue
        }
    }

    private func refresh() async {
        let monthKey = DateKeys.monthKey(Date())
        let month = MonthRepository.upsert(
            monthKey: monthKey,
            requiredOfficeDays: MonthRepository.fetch(monthKey: monthKey, context: context)?.requiredOfficeDays ?? 0,
            context: context)
        await model.refresh(settings: settings, month: month, context: context)
    }
}
