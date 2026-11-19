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
    @Published var imagesData: [Data] = []
    /// Typed `Any` so the class compiles on iOS 13+. Cast to/from
    /// `[PhotosPickerItem]` only inside `@available(iOS 16.0, *)` guards.
    @Published var imagePickerItems: [Any] = []
    @Published var selectedGroupId: String = ""
    @Published var ctaLabel: String = ""
    /// When on, `ctaLabel` is the label of `ctaDefaultLocale` and the app gives its own labels for the languages of
    /// `ctaTranslations`, instead of letting Octopus translate `ctaLabel` automatically.
    @Published var ctaLabelIsPerLanguage = false
    /// The locale identifier of `ctaLabel` when the label is given per language, written by hand so that any
    /// identifier can be tried (`zh-Hant`, `pt_BR`...).
    @Published var ctaDefaultLocale: String = "en"
    @Published var ctaTranslations: [CtaTranslation] = []
    @Published var ctaURLString: String = ""

    /// A label of the CTA in another language, with the locale identifier it is given for.
    struct CtaTranslation: Identifiable {
        let id = UUID()
        var locale: String = ""
        var text: String = ""

        /// A row left untouched, which is not passed to the SDK.
        var isEmpty: Bool { locale.isEmpty && text.isEmpty }
    }

    /// The load of the last picked images, cancelled when the selection changes again so that an older load
    /// cannot overwrite a newer one.
    private var imagesLoadTask: Task<Void, Never>?

    /// Replaces `imagesData` with the data of `items`, or empties it when nothing is selected.
    @available(iOS 16.0, *)
    func loadImages(from items: [PhotosPickerItem]) {
        imagesLoadTask?.cancel()
        guard !items.isEmpty else {
            imagesLoadTask = nil
            imagesData = []
            return
        }
        imagesLoadTask = Task {
            var loaded: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(data)
                }
                if Task.isCancelled { return }
            }
            imagesData = loaded
        }
    }

    /// Replaces `imagesData` with `count` copies of the sample's bundled photo, each stamped with its position so the
    /// editor's order can be checked without picking photos in the library.
    ///
    /// The picker's selection is left as it is: emptying it would trigger `loadImages(from:)`, which would empty
    /// `imagesData` right after.
    func useBundledImages(count: Int) {
        imagesLoadTask?.cancel()
        imagesLoadTask = nil
        let photo = UIImage(resource: .Scenarios.BridgeToClientObject.caneles)
        imagesData = (1...count).compactMap { Self.numbered(photo, number: $0, of: count) }
    }

    private static func numbered(_ photo: UIImage, number: Int, of count: Int) -> Data? {
        // Scaled down so that ten of them stay light: the bundled photo is 2250 px wide.
        let size = CGSize(width: 1200, height: 1200 * photo.size.height / photo.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
            let label = "\(number) / \(count)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 160),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -4
            ]
            let labelSize = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: (size.width - labelSize.width) / 2, y: (size.height - labelSize.height) / 2),
                       withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.8)
    }

    /// The label of the CTA: translated automatically by Octopus, or given per language. A reader whose language is
    /// one of the translations then sees the app's own label, the others an automatic translation.
    ///
    /// The default label and every filled row are passed as they are, so that whatever the SDK rejects (an empty
    /// label, a locale without language, the same language twice) shows the error the integrator would get. Only a
    /// row left completely empty is skipped.
    private func buildCtaLabel() throws -> OctopusLocalizedText {
        guard ctaLabelIsPerLanguage else { return .autoTranslated(ctaLabel) }
        let defaultLocale = Locale(identifier: ctaDefaultLocale)
        var labels = [defaultLocale: ctaLabel]
        for translation in ctaTranslations where !translation.isEmpty {
            let locale = Locale(identifier: translation.locale)
            // Two rows with the same identifier would collapse in the dictionary: report them as the SDK reports
            // two locales that give the same code.
            guard labels.updateValue(translation.text, forKey: locale) == nil else {
                throw OctopusLocalizedText.ValidationError(kind: .duplicateLanguage,
                                                           languageCode: translation.locale)
            }
        }
        return try .perLanguage(labels, defaultLanguage: defaultLocale)
    }

    func addCtaTranslation() {
        ctaTranslations.append(CtaTranslation())
    }

    func removeCtaTranslations(at offsets: IndexSet) {
        ctaTranslations.remove(atOffsets: offsets)
    }

    func buildPrefill() throws -> OctopusPrefilledPost {
        let cta: OctopusPrefilledPost.CTA?
        // In per-language mode, a translation alone is still a CTA the tester asked for: it goes through the
        // validation, which reports what is missing.
        let hasOtherLabel = ctaLabelIsPerLanguage && ctaTranslations.contains { !$0.isEmpty }
        if ctaLabel.isEmpty && ctaURLString.isEmpty && !hasOtherLabel {
            cta = nil
        } else {
            guard let url = URL(string: ctaURLString), !ctaURLString.isEmpty else {
                throw OctopusPrefilledPost.ValidationError.ctaUrlEmpty
            }
            cta = try OctopusPrefilledPost.CTA(url: url, localizedLabel: try buildCtaLabel())
        }
        return try OctopusPrefilledPost(
            text: text.isEmpty ? nil : text,
            images: imagesData,
            topicId: selectedGroupId.isEmpty ? nil : selectedGroupId,
            cta: cta,
            // Sign the share so an image is accepted even in a pictures-off community.
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
            Section(header: Text("Images")) {
                imagePicker
                Button("Use 3 bundled images") {
                    state.useBundledImages(count: 3)
                }
                // One over the SDK's limit of 10, to show the error the integrator would get.
                Button("Use 11 bundled images (too many)") {
                    state.useBundledImages(count: 11)
                }
                if !state.imagesData.isEmpty {
                    Text("\(state.imagesData.count) image(s) selected")
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                    Button("Clear images") {
                        state.imagesData = []
                        state.imagePickerItems = []
                    }
                    .foregroundColor(.red)
                }
            }
            Section(header: Text("Group")) {
                groupPicker
            }
            Section(header: Text("CTA")) {
                Toggle("Give the label per language", isOn: $state.ctaLabelIsPerLanguage)
                if state.ctaLabelIsPerLanguage {
                    HStack {
                        localeField("Default locale", text: $state.ctaDefaultLocale)
                        TextField("Default label", text: $state.ctaLabel)
                    }
                    ForEach($state.ctaTranslations) { $translation in
                        HStack {
                            localeField("Locale", text: $translation.locale)
                            TextField("Label", text: $translation.text)
                        }
                    }
                    .onDelete(perform: state.removeCtaTranslations(at:))
                    Button("Add translation") {
                        state.addCtaTranslation()
                    }
                } else {
                    TextField("Label", text: $state.ctaLabel)
                }
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
                    } catch let error as OctopusLocalizedText.ValidationError {
                        // The error of a label given per language: a separate type too.
                        presentedError = PresentedError(message: error.debugDescription)
                    } catch let error as OctopusPrefilledPost.TooManyImagesError {
                        // A separate error type: the `ValidationError` case above does not catch it.
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

    /// A short field for a locale identifier, typed as it is (`pt-BR`, `zh-Hant-TW`).
    private func localeField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .frame(maxWidth: 110)
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
                .foregroundColor(SampleTokens.Colors.textSecondary)
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

    // Typed binding bridging `[Any]` storage to `[PhotosPickerItem]`
    private var pickerItemsBinding: Binding<[PhotosPickerItem]> {
        Binding(
            get: { state.imagePickerItems.compactMap { $0 as? PhotosPickerItem } },
            set: { state.imagePickerItems = $0 }
        )
    }

    var body: some View {
        let labelText: LocalizedStringKey = state.imagesData.isEmpty ? "Pick images" : "Replace images"
        // No selection limit here on purpose: the SDK enforces the maximum number of images,
        // so picking more than that shows the error the integrator would get.
        PhotosPicker(selection: pickerItemsBinding, matching: .images) {
            Label(labelText, systemImage: "photo.on.rectangle")
        }
        .onChange(of: state.imagePickerItems.compactMap { $0 as? PhotosPickerItem }, perform: { newItems in
            state.loadImages(from: newItems)
        })
    }
}
