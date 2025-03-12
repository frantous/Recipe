//
//  RecipeListViewModel.swift
//  Recipe
//
//  Created by Siran Li on 11/10/24.
//

import Foundation
import SwiftUI

@MainActor
class RecipeListViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let urlSessionManager: NetworkSession
    private let dataDecoder: DataDecoder
    private var task: Task<Void, Never>?
    
    init(dependencies: AppDependencies) {
        self.urlSessionManager = dependencies.networkSession
        self.dataDecoder = dependencies.dataDecoder
    }
    
    func loadRecipes() async {
        // Cancel any ongoing task
        await cancelTask()
        
        isLoading = true
        defer { isLoading = false }
        
        // Create a new task for loading recipes
        task = Task {
            do {
                recipes = try await fetchRecipes()
            } catch {
                errorMessage = handleError(error)
            }
        }
        
        // Wait for the task to complete or be cancelled
        await task?.value
    }
    
    private func fetchRecipes() async throws -> [Recipe] {
        let data = try await fetchRecipeData()
        let recipeResponse = try parseRecipeData(data)
        return recipeResponse.recipes
    }
    
    private func fetchRecipeData() async throws -> Data {
        try await urlSessionManager.fetchData(from: URLConstants.urlString.rawValue)
    }
    
    private func parseRecipeData(_ data: Data) throws -> RecipeResponse {
        let result = dataDecoder.parseData(dataType: RecipeResponse.self, from: data)
        
        switch result {
            case .success(let recipeResponse):
                return recipeResponse
            case .failure(let error):
                throw APIError.decodingError(error)
        }
    }
    
    private func cancelTask() async {
        task?.cancel()
        task = nil
    }
    
    private func handleError(_ error: Error) -> String {
        // Map specific errors to user-friendly messages
        switch error {
            case APIError.invalidURL:
                return "Invalid URL provided."
            case APIError.networkError:
                return "Network error occurred. Please check your connection."
            case APIError.decodingError:
                return "Failed to decode the response. Please try again later."
            default:
                return "An unexpected error occurred."
        }
    }
}
