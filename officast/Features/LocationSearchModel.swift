//
//  LocationSearchModel.swift
//  officast
//
//  Two-step location entry without location permission (D6 / Codex C14):
//  MKLocalSearchCompleter for suggestions → MKLocalSearch to resolve coordinates.
//

import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class LocationSearchModel: NSObject, MKLocalSearchCompleterDelegate {

    var query: String = "" {
        didSet { completer.queryFragment = query }
    }

    var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Resolve a suggestion to a named coordinate (second step).
    func resolve(_ completion: MKLocalSearchCompletion) async -> (name: String, lat: Double, lng: Double)? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first else { return nil }
        let coord = item.location.coordinate
        let name = completion.title.isEmpty ? (item.name ?? "") : completion.title
        return (name, coord.latitude, coord.longitude)
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}
