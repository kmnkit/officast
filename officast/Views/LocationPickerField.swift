//
//  LocationPickerField.swift
//  officast
//
//  Row that shows the chosen place name and opens a search sheet
//  (MKLocalSearchCompleter → MKLocalSearch) to pick a new one.
//

import SwiftUI
import MapKit

struct LocationPickerField: View {
    let title: LocalizedStringKey
    @Binding var name: String
    let onResolved: (_ name: String, _ lat: Double, _ lng: Double) -> Void

    @State private var showingSearch = false

    var body: some View {
        Button {
            showingSearch = true
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(name.isEmpty ? String(localized: "location.notSet") : name)
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .tint(.primary)
        .sheet(isPresented: $showingSearch) {
            LocationSearchSheet { resolvedName, lat, lng in
                name = resolvedName
                onResolved(resolvedName, lat, lng)
                showingSearch = false
            }
        }
    }
}

private struct LocationSearchSheet: View {
    let onPick: (_ name: String, _ lat: Double, _ lng: Double) -> Void

    @State private var search = LocationSearchModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(search.suggestions, id: \.self) { suggestion in
                Button {
                    Task {
                        if let result = await search.resolve(suggestion) {
                            onPick(result.name, result.lat, result.lng)
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(suggestion.title)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .searchable(text: $search.query, prompt: Text("location.searchPrompt"))
            .navigationTitle("location.searchTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}
