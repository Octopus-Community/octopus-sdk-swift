//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to dynamically create posts linked to an object of your app (article, product, item...).
struct BridgeToClientObjectView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = BridgeToClientObjectViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Button(action: { viewModel.recipePushed = stableRecipe }) {
                Text("Canele Recipe")
            }

            Button(action: { viewModel.recipePushed = newRecipe }) {
                Text("Random identifier (new each time the sample is launched)")
            }
            Spacer()

            Button(action: {
                showFullScreen {
                    if let octopus = viewModel.octopus {
                        OctopusUIView(octopus: octopus)
                            .fullScreenCover(item: $viewModel.recipePresented) { recipe in
                                RecipeScreen(recipe: recipe, postIdToDisplay: $viewModel.octopusPostId)
                            }
                    } else {
                        EmptyView()
                    }
                }
            }) {
                Text("Open Octopus Home Screen")
            }
        }
        .padding()
        .background(
            NavigationLink(
                destination: viewModel.recipePushed.map { recipe in
                    RecipeView(recipe: recipe, postIdToDisplay: $viewModel.octopusPostId)
                },
                isActive: Binding(
                    get: { viewModel.recipePushed != nil },
                    set: { isActive in
                        if !isActive {
                            viewModel.recipePushed = nil
                        }
                    }
                ),
                label: { EmptyView() }
            )
        )
        .sheet(isPresented: $viewModel.displayOctopusAsSheet) {
            if let octopus = viewModel.octopus {
                OctopusUIView(octopus: octopus, postId: viewModel.octopusPostId)
                    .fullScreenCover(item: $viewModel.recipePresented) { recipe in
                        RecipeScreen(recipe: recipe, postIdToDisplay: $viewModel.octopusPostId)
                    }
            }
        }
        .onAppear {
            viewModel.configureSDK()
        }
    }
}

private struct RecipeScreen: View {
    @Environment(\.presentationMode) private var presentationMode

    let recipe: Recipe
    @Binding var postIdToDisplay: String?

    var body: some View {
        NavigationView {
            RecipeView(recipe: recipe, postIdToDisplay: $postIdToDisplay)
                .navigationBarItems(
                    trailing:
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                )
                .presentationBackground(Color(.systemBackground))
        }
    }
}

private struct RecipeView: View {
    let recipe: Recipe
    @Binding var postIdToDisplay: String?

    @StateObjectCompat private var viewModel = RecipeViewModel()

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(recipe.title)
                    .font(.headline.bold())
                    .padding()
                ScrollView {
                    VStack {
                        switch recipe.img {
                        case let .local(img):
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case let .remote(url):
                            if #available(iOS 15.0, *) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    let width = geometry.size.width
                                    let aspectRatio = 1936.0 / 2592.0
                                    let height = width * aspectRatio

                                    VStack {
                                        ProgressView()
                                    }
                                    .frame(width: width, height: height)
                                }
                            }
                        case .none:
                            EmptyView()
                        }
                        ZStack {
                            Button(action: {
                                viewModel.getBridgePostId(recipe: recipe)
                            }) {
                                Text(recipe.cta)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor, lineWidth: 1)
                                    )
                            }
                            .disabled(viewModel.isLoading)
                            .opacity(viewModel.isLoading ? 0.1 : 1)
                            if #available(iOS 14.0, *), viewModel.isLoading {
                                ProgressView()
                            }
                        }
                        if #available(iOS 15, *) {
                            Text((try? AttributedString(
                                markdown: recipe.text,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
                            ) ?? AttributedString(recipe.text))
                            .padding()
                        } else {
                            Text(recipe.text)
                                .padding()
                        }
                    }
                }
            }
            .onValueChanged(of: viewModel.octopusPostId) {
                guard $0 != nil else { return }
                postIdToDisplay = $0
                viewModel.octopusPostId = nil
            }
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(
                        "Error",
                        isPresented: Binding(
                            get: { viewModel.error != nil },
                            set: { isActive in
                                if !isActive {
                                    viewModel.error = nil
                                }
                            }
                        ),
                        presenting: viewModel.error,
                        actions: { _ in },
                        message: { error in
                            Text(error.localizedDescription)
                        })
                } else {
                    $0
                }
            }
        }
    }
}

extension Recipe: Identifiable {}
