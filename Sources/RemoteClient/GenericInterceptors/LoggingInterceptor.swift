//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import SwiftProtobuf
import NIOCore
import NIOPosix
import NIOHPACK

class LoggingInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
    let verbose: Bool = false

    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        guard verbose else {
            context.receive(part)
            return
        }
        switch part {
        case .metadata(let metadata):
            print("\n📥 Response Metadata:")
            print(metadata)

        case .message(let message):
            print("\n📥 Response Message:")
            print("Type: \(type(of: message))")
            print("Content: \(message)")

        case .end(let status, let trailers):
            print("\n🏁 Response End")
            print("Status: \(status)")
            print("Trailers: \(trailers)")
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
        switch part {
        case .metadata(let metadata):
            print("🚀 Request Metadata:")
            print(metadata)

        case .message(let message, _):
            print("\n📤 Request Message:")
            print("Type: \(type(of: message))")
            print("Content: \(message)")

        case .end:
            print("\n🏁 Request End")
        }

        context.send(part, promise: promise)
    }
}
