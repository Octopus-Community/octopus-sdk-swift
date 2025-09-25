//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import SwiftProtobuf
import NIOCore
import NIOPosix
import NIOHPACK
import os

class LoggingInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
    let verbose: Bool

    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        guard verbose else {
            context.receive(part)
            return
        }
        if #available(iOS 14, *) {
            switch part {
            case .metadata(let metadata):
                Logger.received.trace("\n📥 Response Metadata: \(metadata)")

            case .message(let message):
                Logger.received.trace("\n📥 Response Message:")
                Logger.received.trace("Type: \(type(of: message))")
                Logger.received.trace("Content: \("\(message)")")

            case .end(let status, let trailers):
                Logger.received.trace("\n🏁 Response End")
                Logger.received.trace("Status: \(status)")
                Logger.received.trace("Trailers: \(trailers)")
            }
        }

        context.receive(part)
    }

    override func send(
        _ part: GRPCClientRequestPart<Request>,
        promise: EventLoopPromise<Void>?,
        context: ClientInterceptorContext<Request, Response>
    ) {
        guard verbose else {
            context.send(part, promise: promise)
            return
        }
        if #available(iOS 14, *) {
            switch part {
            case .metadata(let metadata):
                Logger.sent.trace("🚀 Request Metadata: \(metadata)")

            case .message(let message, _):
                Logger.sent.trace("\n📤 Request Message:")
                Logger.sent.trace("Type: \(type(of: message))")
                Logger.sent.trace("Content: \("\(message)")")

            case .end:
                Logger.sent.trace("\n🏁 Request End")
            }
        }

        context.send(part, promise: promise)
    }
}
