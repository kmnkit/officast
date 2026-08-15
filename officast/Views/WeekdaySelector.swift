//
//  WeekdaySelector.swift
//  officast
//
//  Compact Mon–Sun toggle row for weekly days off (ISO weekday numbers).
//

import SwiftUI

struct WeekdaySelector: View {
    @Binding var offDays: Set<Int>   // ISO weekday: Mon=1 … Sun=7

    private let symbols = Calendar.current.shortWeekdaySymbols  // index 0 = Sunday

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { iso in
                let selected = offDays.contains(iso)
                Button {
                    if selected { offDays.remove(iso) } else { offDays.insert(iso) }
                } label: {
                    Text(shortSymbol(iso))
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(selected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// ISO weekday → localized short symbol (symbols index 0 = Sunday).
    private func shortSymbol(_ iso: Int) -> String {
        let index = iso == 7 ? 0 : iso   // ISO Sun(7)→0, Mon(1)→1 … Sat(6)→6
        return symbols.indices.contains(index) ? symbols[index] : "\(iso)"
    }
}
