//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import SwiftProtobuf
import NIOCore
import NIOPosix
import NIOHPACK
import os

class LoggingInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
    let verbose: Bool

    private let uuid = UUID().uuidString
    private var requestDate: Date?

    // Request buffers
    private var requestMetadata: HPACKHeaders?
    private var requestMessage: Request?

    // Response buffers
    private var responseMetadata: HPACKHeaders?
    private var responseMessage: Response?

    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    override func send(
        _ part: GRPCClientRequestPart<Request>,
        promise: EventLoopPromise<Void>?,
        context: ClientInterceptorContext<Request, Response>
    ) {
        if #available(iOS 14, *) {
            switch part {
            case let .metadata(metadata):
                requestMetadata = metadata

            case let .message(message, _):
                requestMessage = message

            case .end:
                requestDate = Date()
                if verbose {
                    var log = "Sent request to \(context.path) (request \(uuid))"
                    if let metadata = requestMetadata {
                        log += "\n   📇 Metadata: \(metadata)"
                    }
                    if let message = requestMessage {
                        log += "\n  - Type: \(type(of: message))\n  - Content: \(message)"
                    }
                    Logger.sent.trace("\(log)")
                }
            }
        }

        context.send(part, promise: promise)
    }

    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        if #available(iOS 14, *) {
            switch part {
            case let .metadata(metadata):
                responseMetadata = metadata

            case let .message(message):
                responseMessage = message

            case let .end(status, _):
                if verbose {
                    var log = "Received response from \(context.path) (request \(uuid))"
                    if let metadata = responseMetadata { log += "\n  📇 Metadata: \(metadata)" }
                    if let message = responseMessage { log += "\n  Type: \(type(of: message))\n  Content: \(message)" }
                    log += "\n  Status: \(status)"
                    if let requestDate {
                        log += "\n  Took \(Date().timeIntervalSince(requestDate))"
                    }
                    Logger.received.trace("\(log)")
                }
            }
        }

        context.receive(part)
    }
}
