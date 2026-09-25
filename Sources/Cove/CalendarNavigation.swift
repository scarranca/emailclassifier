import CoveCore
import SwiftUI

struct CalendarNavigation: View {
  @Bindable var store: AppStore
  @State private var month = Date()
  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(month, format: .dateTime.month(.wide).year())
          .font(.cove(size: 12, weight: .medium))
        Spacer(minLength: 0)
        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
          .accessibilityLabel("Previous month")
        Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
          .accessibilityLabel("Next month")
      }.buttonStyle(.plain).font(.cove(size: 11))
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
        ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
          Text(day).font(.cove(size: 10)).foregroundStyle(Palette.body).frame(height: 22)
            .accessibilityHidden(true)
        }
        ForEach(CalendarAgenda.monthDays(containing: month), id: \.self) { day in
          let selected = calendar.isDate(day, inSameDayAs: store.calendarDay)
          Button { store.selectCalendarDay(day) } label: {
            Text(day, format: .dateTime.day()).font(.cove(size: 11, weight: selected ? .medium : .regular))
              .frame(maxWidth: .infinity).frame(height: 24)
              .foregroundStyle(selected ? .white : Palette.ink)
              .background(selected ? Palette.ink : .clear, in: Circle())
              .overlay(Circle().stroke(calendar.isDateInToday(day) && !selected ? Palette.ink : .clear))
              .opacity(calendar.isDate(day, equalTo: month, toGranularity: .month) ? 1 : 0.5)
          }.buttonStyle(.plain)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
      Divider()
      Text("My calendars").font(.cove(size: 12, weight: .medium))
      Text("On this Mac").font(.cove(size: 10)).foregroundStyle(Palette.muted)
      ForEach(LocalCalendar.allCases, id: \.self) { calendar in
        Toggle(calendar.title, isOn: Binding(
          get: { store.isLocalCalendarVisible(calendar) },
          set: { store.setLocalCalendar(calendar, visible: $0) }
        ))
      }
      if store.calendarConnected && !store.isSample {
        Toggle("Google · primary", isOn: $store.showGoogleCalendar)
      }
    }.font(.cove(size: 12)).toggleStyle(.checkbox)
      .onAppear { month = store.calendarDay }
      .onChange(of: store.calendarDay) { _, day in month = day }
  }
  private func moveMonth(_ amount: Int) {
    let start = calendar.dateInterval(of: .month, for: month)?.start ?? month
    month = calendar.date(byAdding: .month, value: amount, to: start) ?? start
  }
}
