//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder 
    nonisolated func alert<A, M, T>(
        _ title: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?,
        @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A : View, M : View {
            if #available(iOS 15.0, *) {
                self.alert(
                    Text(title, bundle: .module),
                    isPresented: isPresented,
                    presenting: data,
                    actions: actions,
                    message: message)
            } else {
                self.alert(isPresented: isPresented, content: {
                    Alert(
                        title: Text(title, bundle: .module),
                        message: data.map { message($0) } as? Text ?? Text(verbatim: "")
                    )
                })
            }
        }
}
