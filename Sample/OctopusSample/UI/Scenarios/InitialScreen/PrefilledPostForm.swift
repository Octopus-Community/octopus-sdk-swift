//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import PhotosUI
import Octopus

@MainActor
final class PrefilledPostFormState: ObservableObject {
    @Published var text: String = ""
    @Published var imageData: Data?
    /// Typed `Any?` so the class compiles on iOS 13+. Cast to/from
    /// `PhotosPickerItem` only inside `@available(iOS 16.0, *)` guards.
    @Published var imagePickerItem: Any?
    @Published var selectedGroupId: String = ""
    @Published var ctaLabel: String = ""
    @Published var ctaURLString: String = ""

    func buildPrefill() throws -> OctopusPrefilledPost {
        let cta: OctopusPrefilledPost.CTA?
        if ctaLabel.isEmpty && ctaURLString.isEmpty {
            cta = nil
        } else {
            guard let url = URL(string: ctaURLString), !ctaURLString.isEmpty else {
                throw OctopusPrefilledPost.ValidationError.ctaUrlEmpty
            }
            cta = try OctopusPrefilledPost.CTA(url: url, label: ctaLabel)
        }
        return try OctopusPrefilledPost(
            text: text.isEmpty ? nil : text,
            image: imageData,
            topicId: selectedGroupId.isEmpty ? nil : selectedGroupId,
            cta: cta,
            // OCT-1426: sign the share so an image is accepted even in a pictures-off community.
            // In a real app this calls your backend; here the sample signs locally with its test secret.
            sign: { fingerprint in try TokenProvider().getBridgeSignature(bridgeFingerprint: fingerprint) }
        )
    }
}

struct PrefilledPostForm: View {
    @ObservedObject var state: PrefilledPostFormState
    let groups: [OctopusGroup]
    let onOpen: (OctopusPrefilledPost) -> Void

    @State private var presentedError: PresentedError?

    var body: some View {
        Form {
            Section(header: Text("Text")) {
                textEditor
            }
            Section(header: Text("Image")) {
                imagePicker
                if state.imageData != nil {
                    Button("Clear image") {
                        state.imageData = nil
                        state.imagePickerItem = nil
                    }
                    .foregroundColor(.red)
                }
            }
            Section(header: Text("Group")) {
                groupPicker
            }
            Section(header: Text("CTA")) {
                TextField("Label", text: $state.ctaLabel)
                TextField("URL (https:// or custom scheme)", text: $state.ctaURLString)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            Section {
                Button("Open Octopus") {
                    do {
                        let prefill = try state.buildPrefill()
                        onOpen(prefill)
                    } catch let error as OctopusPrefilledPost.ValidationError {
                        presentedError = PresentedError(message: error.debugDescription)
                    } catch {
                        presentedError = PresentedError(message: "Unexpected error: \(error)")
                    }
                }
            }
        }
        .alert(item: $presentedError) { err in
            Alert(title: Text("Prefill rejected"),
                  message: Text(err.message),
                  dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private var textEditor: some View {
        if #available(iOS 14.0, *) {
            TextEditor(text: $state.text)
                .frame(minHeight: 80)
        } else {
            TextField("Post text", text: $state.text)
        }
    }

    @ViewBuilder
    private var imagePicker: some View {
        if #available(iOS 16.0, *) {
            ImagePickerView(state: state)
        } else {
            Text("Image picking requires iOS 16+ in the sample app.")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var groupPicker: some View {
        let picker = Picker(selection: $state.selectedGroupId, label: Text("Group")) {
            Text("None").tag("")
            ForEach(groups, id: \.id) { group in
                Text(group.name).tag(group.id as String)
            }
        }
        if #available(iOS 14.0, *) {
            picker.pickerStyle(.menu)
        } else {
            picker
        }
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

@available(iOS 16.0, *)
private struct ImagePickerView: View {
    @ObservedObject var state: PrefilledPostFormState

    // Typed binding bridging `Any?` storage to `PhotosPickerItem?`
    private var pickerItemBinding: Binding<PhotosPickerItem?> {
        Binding(
            get: { state.imagePickerItem as? PhotosPickerItem },
            set: { state.imagePickerItem = $0 }
        )
    }

    var body: some View {
        let labelText: LocalizedStringKey = state.imageData == nil ? "Pick an image" : "Replace image"
        PhotosPicker(selection: pickerItemBinding, matching: .images) {
            Label(labelText, systemImage: "photo")
        }
        .onChange(of: state.imagePickerItem as? PhotosPickerItem, perform: { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { state.imageData = data }
                }
            }
        })
    }
}
