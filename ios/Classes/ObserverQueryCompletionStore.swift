//
//  ObserverQueryCompletionStore.swift
//  health_kit_reporter
//

import Foundation
import HealthKit

/// Holds the completion handlers of observer query background deliveries
/// until the Flutter side reports that it finished handling the update.
/// A pending completion is called anyway after `timeout`, since HealthKit
/// stops background deliveries for apps that fail to respond.
final class ObserverQueryCompletionStore {
    static let shared = ObserverQueryCompletionStore()

    private let timeout: TimeInterval = 25
    private let queue = DispatchQueue(label: "health_kit_reporter.observer_query_completion")
    private var completions = [String: HKObserverQueryCompletionHandler]()

    func add(_ completion: @escaping HKObserverQueryCompletionHandler) -> String {
        let id = UUID().uuidString
        queue.sync {
            completions[id] = completion
        }
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(id: id)
        }
        return id
    }

    func complete(id: String) {
        queue.async { [weak self] in
            self?.finish(id: id)
        }
    }

    private func finish(id: String) {
        completions.removeValue(forKey: id)?()
    }
}
