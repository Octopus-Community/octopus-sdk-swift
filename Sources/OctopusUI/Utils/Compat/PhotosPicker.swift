//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selection: [ImageAndData]
    @Binding var error: Error?

    private let sourceType: UIImagePickerController.SourceType = .photoLibrary


    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator

        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 1) {
                parent.selection = [ImageAndData(imageData: data, image: image)]
            } else {
                parent.error = NSError(domain: "Image Parsing", code: 1)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

@available(iOS 16.0, *)
struct PhotosPicker<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding var selection: [ImageAndData]
    @Binding var error: Error?
    let maxSelectionCount: Int

    @ViewBuilder let content: Content

    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $selectedItems, maxSelectionCount: maxSelectionCount,
                          matching: .images)
            .onChange(of: selectedItems) { selectedItems in
                // make it run on main actor to avoid closing the picker without the image being available
                Task { @MainActor in
                    var selection = [ImageAndData]()
                    for selectedItem in selectedItems {
                        do {
                            guard let imageData = try await selectedItem.loadTransferable(type: Data.self),
                                  let image = UIImage(data: imageData) else {
                                self.error = NSError(domain: "Image Parsing", code: 1)
                                continue
                            }
                            selection.append(ImageAndData(imageData: imageData, image: image))
                        } catch {
                            self.error = error
                        }
                    }
                    self.selection = selection
                }
            }
            .onChange(of: selection) { selection in
                if selection.isEmpty {
                    selectedItems = []
                }
            }
    }
}

struct ImageAndData: Equatable {
    let imageData: Data
    let image: UIImage
}

extension View {
    @ViewBuilder
    func imagesPicker(isPresented: Binding<Bool>, selection: Binding<[ImageAndData]>, error: Binding<(any Error)?>,
                      maxSelectionCount: Int) -> some View {
        if #available(iOS 16.0, *) {
            PhotosPicker(isPresented: isPresented, selection: selection, error: error,
                         maxSelectionCount: maxSelectionCount) {
                self
            }
        } else {
            self.sheet(isPresented: isPresented) {
                ImagePicker(selection: selection, error: error) // only 1 selection for this class
            }
        }
    }
}
