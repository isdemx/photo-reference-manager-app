//
//  ShareViewController.swift
//  RefmaShare
//
//  Created by Sergey Kudryashov on 25/12/2025.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    private let appGroupId = "group.app.greenmonster.photoreferencemanager"
    private let inboxFolderName = "SharedInbox"
    private let manifestKey = "refma.shared.import.manifest"

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let group = DispatchGroup()
        let manifestQueue = DispatchQueue(label: "refma.share.manifest.queue")
        var newEntries: [[String: Any]] = []

        let typeImage = kUTTypeImage as String
        let typeMovie = kUTTypeMovie as String
        let typeFileURL = kUTTypeFileURL as String
        let typeData = kUTTypeData as String

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(typeImage) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeImage, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "image") {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeMovie) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeMovie, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "video") {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeFileURL) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeFileURL, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeData) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeData, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            self.appendToManifest(entries: newEntries)
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func appGroupInboxURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let inbox = container.appendingPathComponent(inboxFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: inbox.path) {
            try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        }
        return inbox
    }

    private func handleLoadedItem(_ item: NSSecureCoding?, mediaTypeHint: String?) -> [String: Any]? {
        if let url = item as? URL {
            return copyFile(from: url, mediaTypeHint: mediaTypeHint)
        }
        if let image = item as? UIImage {
            guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
            return writeData(data, ext: "jpg", originalName: "shared.jpg", mediaType: "image")
        }
        if let data = item as? Data {
            return writeData(data, ext: "bin", originalName: "shared.bin", mediaType: mediaTypeHint ?? "file")
        }
        return nil
    }

    private func copyFile(from url: URL, mediaTypeHint: String?) -> [String: Any]? {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let inbox = appGroupInboxURL() else { return nil }

        let originalName = url.lastPathComponent
        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        let targetName = "\(UUID().uuidString).\(ext)"
        let dest = inbox.appendingPathComponent(targetName)

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            return nil
        }

        let mediaType = mediaTypeHint ?? inferMediaType(fromExtension: ext)
        return [
            "fileName": targetName,
            "relativePath": "\(inboxFolderName)/\(targetName)",
            "originalName": originalName,
            "mediaType": mediaType,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    private func writeData(_ data: Data, ext: String, originalName: String, mediaType: String) -> [String: Any]? {
        guard let inbox = appGroupInboxURL() else { return nil }

        let targetName = "\(UUID().uuidString).\(ext)"
        let dest = inbox.appendingPathComponent(targetName)

        do {
            try data.write(to: dest)
        } catch {
            return nil
        }

        return [
            "fileName": targetName,
            "relativePath": "\(inboxFolderName)/\(targetName)",
            "originalName": originalName,
            "mediaType": mediaType,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    private func inferMediaType(fromExtension ext: String) -> String {
        let lower = ext.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "bmp", "webp"]
        let videoExts = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
        if imageExts.contains(lower) { return "image" }
        if videoExts.contains(lower) { return "video" }
        return "file"
    }

    private func appendToManifest(entries: [[String: Any]]) {
        guard !entries.isEmpty else { return }
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }

        let existing = defaults.array(forKey: manifestKey) as? [[String: Any]] ?? []
        let updated = existing + entries
        defaults.set(updated, forKey: manifestKey)
        defaults.synchronize()
    }
}
