//
//  ShareViewController.swift
//  RefmaShare
//
//  Created by Sergey Kudryashov on 25/12/2025.
//

import UIKit
import Social
import MobileCoreServices

final class ShareItem {
    let provider: NSItemProvider
    let typeIdentifier: String
    var thumbnail: UIImage?
    var compress: Bool

    init(provider: NSItemProvider, typeIdentifier: String, compress: Bool) {
        self.provider = provider
        self.typeIdentifier = typeIdentifier
        self.compress = compress
    }
}

final class ShareItemCell: UITableViewCell {
    static let reuseId = "ShareItemCell"

    private let thumbImageView = UIImageView()
    private let compressLabel = UILabel()
    private let compressSwitch = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 6

        compressLabel.translatesAutoresizingMaskIntoConstraints = false
        compressLabel.text = "Compress"
        compressLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        compressLabel.textColor = .secondaryLabel

        compressSwitch.translatesAutoresizingMaskIntoConstraints = false
        compressSwitch.addTarget(self, action: #selector(handleToggle), for: .valueChanged)

        contentView.addSubview(thumbImageView)
        contentView.addSubview(compressLabel)
        contentView.addSubview(compressSwitch)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.heightAnchor.constraint(equalToConstant: 56),
            thumbImageView.widthAnchor.constraint(equalToConstant: 56),

            compressSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            compressSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            compressLabel.trailingAnchor.constraint(equalTo: compressSwitch.leadingAnchor, constant: -8),
            compressLabel.centerYAnchor.constraint(equalTo: compressSwitch.centerYAnchor),

            thumbImageView.trailingAnchor.constraint(lessThanOrEqualTo: compressLabel.leadingAnchor, constant: -12)
        ])

        backgroundColor = .clear
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(thumbnail: UIImage?, compress: Bool, onToggle: @escaping (Bool) -> Void) {
        thumbImageView.image = thumbnail ?? UIImage(systemName: "photo")
        compressSwitch.isOn = compress
        self.onToggle = onToggle
    }

    @objc private func handleToggle() {
        onToggle?(compressSwitch.isOn)
    }
}

class ShareViewController: SLComposeServiceViewController, UITableViewDataSource, UITableViewDelegate {
    private let appGroupId = "group.app.greenmonster.photoreferencemanager"
    private let inboxFolderName = "SharedInbox"
    private let manifestKey = "refma.shared.import.manifest"

    private var shareItems: [ShareItem] = []
    private let itemsTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let compressAllSwitch = UISwitch()
    private let addButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadShareItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.rightBarButtonItem?.title = "Add"
    }

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
                    let compress = compressSetting(for: provider)
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeImage, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "image", compress: compress) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeMovie) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeMovie, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "video", compress: false) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeFileURL) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeFileURL, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeData) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeData, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false) {
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

    private func setupUI() {
        title = "Import"
        navigationItem.rightBarButtonItem?.title = "Add"
        textView.isHidden = true
        textView.isEditable = false
        textView.isUserInteractionEnabled = false
        textView.heightAnchor.constraint(equalToConstant: 0).isActive = true

        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "Compress all"
        headerLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        headerLabel.textColor = .label

        compressAllSwitch.translatesAutoresizingMaskIntoConstraints = false
        compressAllSwitch.addTarget(self, action: #selector(handleCompressAll), for: .valueChanged)

        headerView.addSubview(headerLabel)
        headerView.addSubview(compressAllSwitch)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            compressAllSwitch.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            compressAllSwitch.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        itemsTableView.translatesAutoresizingMaskIntoConstraints = false
        itemsTableView.dataSource = self
        itemsTableView.delegate = self
        itemsTableView.rowHeight = 76
        itemsTableView.tableFooterView = UIView()
        itemsTableView.separatorStyle = .none
        itemsTableView.backgroundColor = .clear
        itemsTableView.register(ShareItemCell.self, forCellReuseIdentifier: ShareItemCell.reuseId)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("Add", for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        addButton.backgroundColor = UIColor(red: 35.0/255.0, green: 107.0/255.0, blue: 166.0/255.0, alpha: 1.0)
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 10
        addButton.addTarget(self, action: #selector(handleAdd), for: .touchUpInside)

        view.addSubview(headerView)
        view.addSubview(itemsTableView)
        view.addSubview(addButton)
        view.backgroundColor = .systemGroupedBackground

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            itemsTableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            itemsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            itemsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            itemsTableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            addButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func loadShareItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        let typeImage = kUTTypeImage as String
        var collected: [ShareItem] = []

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers where provider.hasItemConformingToTypeIdentifier(typeImage) {
                collected.append(ShareItem(provider: provider, typeIdentifier: typeImage, compress: false))
            }
        }

        shareItems = collected
        updateCompressAllSwitch()
        itemsTableView.reloadData()

        for (index, item) in shareItems.enumerated() {
            loadPreview(for: item, at: index)
        }
    }

    private func loadPreview(for item: ShareItem, at index: Int) {
        item.provider.loadPreviewImage(options: nil) { preview, _ in
            var image: UIImage?
            if let uiImage = preview as? UIImage {
                image = uiImage
            } else if let url = preview as? URL {
                image = UIImage(contentsOfFile: url.path)
            }

            if image == nil {
                item.provider.loadItem(forTypeIdentifier: item.typeIdentifier, options: nil) { data, _ in
                    var fallback: UIImage?
                    if let url = data as? URL {
                        fallback = UIImage(contentsOfFile: url.path)
                    } else if let uiImage = data as? UIImage {
                        fallback = uiImage
                    } else if let raw = data as? Data {
                        fallback = UIImage(data: raw)
                    }
                    DispatchQueue.main.async {
                        item.thumbnail = fallback
                        self.itemsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                item.thumbnail = image
                self.itemsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
        }
    }

    @objc private func handleCompressAll() {
        for item in shareItems {
            item.compress = compressAllSwitch.isOn
        }
        itemsTableView.reloadData()
    }

    @objc private func handleAdd() {
        addButton.isEnabled = false
        addButton.alpha = 0.6
        didSelectPost()
    }

    private func updateCompressAllSwitch() {
        let allOn = !shareItems.isEmpty && shareItems.allSatisfy { $0.compress }
        compressAllSwitch.isOn = allOn
    }

    private func compressSetting(for provider: NSItemProvider) -> Bool {
        for item in shareItems where item.provider === provider {
            return item.compress
        }
        return false
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shareItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareItemCell.reuseId, for: indexPath) as? ShareItemCell else {
            return UITableViewCell()
        }
        let item = shareItems[indexPath.row]
        cell.configure(thumbnail: item.thumbnail, compress: item.compress) { [weak self] isOn in
            guard let self = self else { return }
            item.compress = isOn
            self.updateCompressAllSwitch()
        }
        return cell
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

    private func handleLoadedItem(_ item: NSSecureCoding?, mediaTypeHint: String?, compress: Bool) -> [String: Any]? {
        if let url = item as? URL {
            return copyFile(from: url, mediaTypeHint: mediaTypeHint, compress: compress)
        }
        if let image = item as? UIImage {
            guard let data = image.pngData() else { return nil }
            return writeData(data, ext: "png", originalName: "shared.png", mediaType: "image", compress: compress)
        }
        if let data = item as? Data {
            if mediaTypeHint == "image" {
                let ext = inferImageExtension(from: data)
                let name = ext.isEmpty ? "shared" : "shared.\(ext)"
                return writeData(data, ext: ext.isEmpty ? "img" : ext, originalName: name, mediaType: "image", compress: compress)
            }
            return writeData(data, ext: "bin", originalName: "shared.bin", mediaType: mediaTypeHint ?? "file", compress: compress)
        }
        return nil
    }

    private func copyFile(from url: URL, mediaTypeHint: String?, compress: Bool) -> [String: Any]? {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let inbox = appGroupInboxURL() else { return nil }

        let originalName = url.lastPathComponent
        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        let mediaType = mediaTypeHint ?? inferMediaType(fromExtension: ext)

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

        return [
            "fileName": targetName,
            "relativePath": "\(inboxFolderName)/\(targetName)",
            "originalName": originalName,
            "mediaType": mediaType,
            "compress": compress,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    private func writeData(_ data: Data, ext: String, originalName: String, mediaType: String, compress: Bool) -> [String: Any]? {
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
            "compress": compress,
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

    private func inferImageExtension(from data: Data) -> String {
        if data.count >= 3 {
            let bytes = [UInt8](data.prefix(12))
            if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
                return "jpg"
            }
            if bytes.count >= 4, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
                return "png"
            }
            if bytes.count >= 6, bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46 {
                return "gif"
            }
            if bytes.count >= 12, bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
               bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
                return "webp"
            }
        }
        return ""
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
