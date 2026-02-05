//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


import Foundation
import Combine
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
import OctopusDependencyInjection
import os
import UIKit

extension Injected {
    static let sdkEventsEmitter = Injector.InjectedIdentifier<SdkEventsEmitter>()
}

/// Object responsible of emitting some internal SDK events
public class SdkEventsEmitter: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.sdkEventsEmitter

    public var internalEvents: AnyPublisher<InternalSdkEvent, Never> { _internalEvents.eraseToAnyPublisher() }
    private let _internalEvents = PassthroughSubject<InternalSdkEvent, Never>()

    public var events: AnyPublisher<SdkEvent, Never> { _events.eraseToAnyPublisher() }
    private let _events = PassthroughSubject<SdkEvent, Never>()

    init(injector: Injector) { }

    func emit(_ event: InternalSdkEvent) {
        DispatchQueue.main.async { [weak self] in
            self?._internalEvents.send(event)
        }
    }

    public func emit(_ event: SdkEvent) {
        DispatchQueue.main.async { [weak self] in
            self?._events.send(event)
        }
    }
}
