//
//  CachedAsyncImageViewModel.swift
//  Recipe
//
//  Created by Siran Li on 2/1/25.
//

import SwiftUI

@MainActor
class CachedAsyncImageViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let networkSession: NetworkSession
    private let imageMemoryCache: MemoryCache
    private let imageDiskCache: DiskCache
    private var task: Task<Void, Never>?
    
    init(dependencies: AppDependencies) {
        self.networkSession = dependencies.networkSession
        self.imageMemoryCache = dependencies.imageMemoryCache
        self.imageDiskCache = dependencies.imageDiskCache
    }
    
    func loadImage(from url: String) async {
        // Cancel any ongoing task
        await cancelTask()
        
        isLoading = true
        defer { isLoading = false }
        
        task = Task {
            do {
                let image = try await fetchImage(forKey: url)
                await MainActor.run {
                    self.image = image
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading image: \(error)"
                }
            }
        }
    }
    
    private func fetchImage(forKey url: String) async throws -> UIImage? {
        guard let imageURL = URL(string: url) else {
            throw APIError.invalidURL
        }
        let key = createKey(from: url)
        
        if let cachedImage = getImageFromCache(forKey: key) {
            return cachedImage
        }
        
        let imageData = try await networkSession.fetchData(from: imageURL.absoluteString)
        if let fetchedImage = UIImage(data: imageData) {
            cacheImage(fetchedImage, forKey: key)
            return fetchedImage
        }
        return nil
    }
    
    private func getImageFromCache(forKey key: String) -> UIImage? {
        if let cachedImage = imageMemoryCache.fetch(forKey: key) {
            return cachedImage
        }
        do {
            return try imageDiskCache.retrieve(forKey: key)
        } catch {
            print("Error fetching image from cache: \(error)")
            return nil
        }
    }
    
    private func cacheImage(_ image: UIImage, forKey key: String) {
        imageMemoryCache.cache(image, forKey: key)
        do {
            try imageDiskCache.store(image, forKey: key)
        } catch {
            print("Error saving image to disk: \(error)")
        }
    }
    
    private func createKey(from urlString: String) -> String {
        let invalidCharacters = "/\\:*?\"<>|."
        return urlString.replacingOccurrences(of: "[\(invalidCharacters)]", with: "#", options: .regularExpression)
    }
    
    private func cancelTask() async {
        task?.cancel()
        task = nil
    }
}
