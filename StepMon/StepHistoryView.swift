//
//  StepHistoryView.swift
//  StepMon
//
//  Created by Antigravity on 3/7/26.
//

import SwiftUI
import Charts

struct StepHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StepHistoryViewModel()
    @State private var selectedRange: Int = 7 // 7 or 30
    @State private var selectedDate: Date? = nil
    @State private var hapticDate: Date? = nil // 햅틱 트리거용
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 다크모드 및 시스템 테마 대응
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Picker("기간 선택", selection: $selectedRange) {
                        Text("7일").tag(7)
                        Text("30일").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("데이터를 가져오는 중...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 25) {
                                // 요약 카드
                                summaryCard
                                
                                // 차트 카드
                                chartCard
                                    .sensoryFeedback(.selection, trigger: hapticDate)
                                
                                // 상세 리스트
                                historyList
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("걸음수 통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchHistory()
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedRange == 7 ? "주간 평균" : "월간 평균")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(selectedRange == 7 ? viewModel.averageWeeklySteps : viewModel.averageMonthlySteps)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("걸음")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("활동 추이")
                .font(.headline)
            
            Chart {
                let data = selectedRange == 7 ? viewModel.weeklySteps : viewModel.monthlySteps
                ForEach(data) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("걸음수", item.steps)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(selectedRange == 7 ? 4 : 2)
                    .opacity(selectedDate == nil || Calendar.current.isDate(item.date, inSameDayAs: selectedDate!) ? 1.0 : 0.5)
                }
                
                // 평균선
                RuleMark(
                    y: .value("평균", selectedRange == 7 ? viewModel.averageWeeklySteps : viewModel.averageMonthlySteps)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.orange)
                .annotation(position: .top, alignment: .trailing) {
                    if selectedDate == nil {
                        Text("평균")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                // 선택된 지점 가이드라인 및 툴팁
                if let selectedDate,
                   let selectedItem = (selectedRange == 7 ? viewModel.weeklySteps : viewModel.monthlySteps)
                    .first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    
                    RuleMark(x: .value("날짜", selectedDate, unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .zIndex(-1)
                        .annotation(
                            position: .top, spacing: 0,
                            overflowResolution: .init(x: .fit, y: .disabled)
                        ) {
                            VStack(spacing: 4) {
                                Text(selectedItem.date, format: .dateTime.month().day().weekday())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(selectedItem.steps)보")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                            .offset(y: -30) // 손가락 위로 충분히 띄움
                        }
                }
            }
            .frame(height: 200)
            .chartXSelection(value: $selectedDate)
            .onChange(of: selectedDate) { oldValue, newValue in
                if let newValue {
                    let newDay = Calendar.current.startOfDay(for: newValue)
                    if hapticDate != newDay {
                        hapticDate = newDay
                    }
                } else {
                    hapticDate = nil
                }
            }
            .chartXAxis {
                if selectedRange == 7 {
                    // 7일: 요일 한 글자로 표시하여 겹침 방지 (M, T, W...)
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                } else {
                    // 30일: 7일 단위로 날짜만 표시
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
            }
            .chartXScale(domain: chartDomain)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var chartDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -(selectedRange - 1), to: calendar.startOfDay(for: now))!
        return start...now
    }
    
    private var historyList: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("상세 기록")
                .font(.headline)
            
            let data = (selectedRange == 7 ? viewModel.weeklySteps : viewModel.monthlySteps).reversed()
            
            ForEach(data) { item in
                HStack {
                    // 날짜 한글 형태 유지 (다국어 시 시스템 설정 따름)
                    Text(item.date, format: .dateTime.month().day().weekday())
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.steps)보")
                        .font(.subheadline.bold())
                }
                if item.id != data.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}


// 다크모드 체크를 위한 확장
extension Color {
    static var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }
}


#Preview {
    StepHistoryView()
}
