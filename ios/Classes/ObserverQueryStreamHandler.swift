//
//  ObserverQueryStreamHandler.swift
//  health_kit_reporter
//
//  Created by Victor Kachalov on 08.12.20.
//

import Foundation
import HealthKit
import HealthKitReporter

public final class ObserverQueryStreamHandler: NSObject {
    public let reporter: HealthKitReporter
    public var activeQueries = Set<Query>()
    public var plannedQueries = Set<Query>()

    init(reporter: HealthKitReporter) {
        self.reporter = reporter
    }
}
// MARK: - StreamHandlerProtocol
extension ObserverQueryStreamHandler: StreamHandlerProtocol {
    public func setQueries(arguments: [String: Any], events: @escaping FlutterEventSink) throws {
        guard
            let identifiers = arguments["identifiers"] as? [String]
        else {
            return
        }
        var predicate: NSPredicate?
        if
            let startTimestamp = arguments["startTimestamp"] as? Double,
            let endTimestamp = arguments["endTimestamp"] as? Double {
            predicate = NSPredicate.samplesPredicate(
                startDate: Date.make(from: startTimestamp),
                endDate: Date.make(from: endTimestamp)
            )
        }
        for identifier in identifiers {
            guard let type = identifier.objectType as? SampleType else {
                return
            }
            guard let sampleType = type.original as? HKSampleType else {
                throw HealthKitError.invalidType("Invalid HKQuantityType: \(type)")
            }
            // Created directly instead of through reporter.observer.observerQuery, which calls
            // the completion handler itself right away. Here it is called only after Flutter
            // finishes handling the update.
            let query = HKObserverQuery(
                sampleType: sampleType,
                predicate: predicate
            ) { (query, completion, error) in
                guard
                    error == nil,
                    let identifier = query.identifier
                else {
                    return
                }
                let completionId = ObserverQueryCompletionStore.shared.add(completion)
                DispatchQueue.main.async {
                    events(["identifier": identifier, "completionId": completionId])
                }
            }
            plannedQueries.insert(query)
        }
    }

    public static func make(with reporter: HealthKitReporter) -> ObserverQueryStreamHandler {
        ObserverQueryStreamHandler(reporter: reporter)
    }
}
// MARK: - FlutterStreamHandler
extension ObserverQueryStreamHandler: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        handleOnListen(withArguments: arguments, eventSink: events)
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        handleOnCancel(withArguments: arguments)
    }
}
