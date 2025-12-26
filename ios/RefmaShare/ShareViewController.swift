//
//  ShareViewController.swift
//  RefmaShare
//
//  Created by Sergey Kudryashov on 25/12/2025.
//

import UIKit
import Social
import MobileCoreServices

struct SharedTag {
    let id: String
    let name: String
    let colorValue: Int
}

final class ShareItem {
    let provider: NSItemProvider
    let typeIdentifier: String
    var thumbnail: UIImage?
    var compress: Bool
    var selectedTagIds: Set<String>

    init(provider: NSItemProvider, typeIdentifier: String, compress: Bool) {
        self.provider = provider
        self.typeIdentifier = typeIdentifier
        self.compress = compress
        self.selectedTagIds = []
    }
}

final class TagChipButton: UIButton {
    let tagModel: SharedTag

    init(tag: SharedTag, selected: Bool) {
        self.tagModel = tag
        super.init(frame: .zero)
        setTitle(tag.name, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        setTitleColor(.white, for: .normal)
        backgroundColor = TagChipButton.colorFromFlutter(tag.colorValue)
            .withAlphaComponent(selected ? 1.0 : 0.4)
        layer.cornerRadius = 12
        contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func colorFromFlutter(_ value: Int) -> UIColor {
        let v = UInt32(truncatingIfNeeded: value)
        let a = CGFloat((v >> 24) & 0xFF) / 255.0
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

final class SelectedTagChip: UIButton {
    let tagModel: SharedTag

    init(tag: SharedTag) {
        self.tagModel = tag
        super.init(frame: .zero)
        setTitle(tag.name, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        setTitleColor(.white, for: .normal)
        backgroundColor = TagChipButton.colorFromFlutter(tag.colorValue)
        layer.cornerRadius = 10
        contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ShareItemCell: UITableViewCell {
    static let reuseId = "ShareItemCell"

    private let thumbImageView = UIImageView()
    private let compressLabel = UILabel()
    private let compressSwitch = UISwitch()
    private let selectedTagsScrollView = UIScrollView()
    private let selectedTagsStack = UIStackView()

    private var onToggleCompress: ((Bool) -> Void)?
    private var onRemoveTag: ((SharedTag) -> Void)?

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

        selectedTagsScrollView.translatesAutoresizingMaskIntoConstraints = false
        selectedTagsScrollView.showsHorizontalScrollIndicator = false

        selectedTagsStack.translatesAutoresizingMaskIntoConstraints = false
        selectedTagsStack.axis = .horizontal
        selectedTagsStack.spacing = 8
        selectedTagsStack.alignment = .center

        selectedTagsScrollView.addSubview(selectedTagsStack)

        contentView.addSubview(thumbImageView)
        contentView.addSubview(compressLabel)
        contentView.addSubview(compressSwitch)
        contentView.addSubview(selectedTagsScrollView)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            thumbImageView.widthAnchor.constraint(equalToConstant: 56),
            thumbImageView.heightAnchor.constraint(equalToConstant: 56),

            compressSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            compressSwitch.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            compressLabel.trailingAnchor.constraint(equalTo: compressSwitch.leadingAnchor, constant: -8),
            compressLabel.centerYAnchor.constraint(equalTo: compressSwitch.centerYAnchor),

            selectedTagsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectedTagsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectedTagsScrollView.topAnchor.constraint(equalTo: thumbImageView.bottomAnchor, constant: 8),
            selectedTagsScrollView.heightAnchor.constraint(equalToConstant: 26),
            selectedTagsScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            selectedTagsStack.leadingAnchor.constraint(equalTo: selectedTagsScrollView.leadingAnchor, constant: 16),
            selectedTagsStack.trailingAnchor.constraint(equalTo: selectedTagsScrollView.trailingAnchor, constant: -16),
            selectedTagsStack.topAnchor.constraint(equalTo: selectedTagsScrollView.topAnchor),
            selectedTagsStack.bottomAnchor.constraint(equalTo: selectedTagsScrollView.bottomAnchor),
            selectedTagsStack.heightAnchor.constraint(equalTo: selectedTagsScrollView.heightAnchor)
        ])

        backgroundColor = .clear
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        thumbnail: UIImage?,
        compress: Bool,
        selectedTags: [SharedTag],
        onToggleCompress: @escaping (Bool) -> Void,
        onRemoveTag: @escaping (SharedTag) -> Void
    ) {
        thumbImageView.image = thumbnail ?? UIImage(systemName: "photo")
        compressSwitch.isOn = compress
        self.onToggleCompress = onToggleCompress
        self.onRemoveTag = onRemoveTag

        selectedTagsStack.arrangedSubviews.forEach { view in
            selectedTagsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if selectedTags.isEmpty {
            let placeholder = UILabel()
            placeholder.text = "No tags"
            placeholder.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            placeholder.textColor = .secondaryLabel
            selectedTagsStack.addArrangedSubview(placeholder)
            return
        }

        for tag in selectedTags {
            let chip = SelectedTagChip(tag: tag)
            chip.addTarget(self, action: #selector(handleRemoveTag(_:)), for: .touchUpInside)
            selectedTagsStack.addArrangedSubview(chip)
        }
    }

    @objc private func handleToggle() {
        onToggleCompress?(compressSwitch.isOn)
    }

    @objc private func handleRemoveTag(_ sender: SelectedTagChip) {
        onRemoveTag?(sender.tagModel)
    }
}

class ShareViewController: SLComposeServiceViewController, UITableViewDataSource, UITableViewDelegate {
    private let appGroupId = "group.app.greenmonster.photoreferencemanager"
    private let inboxFolderName = "SharedInbox"
    private let manifestKey = "refma.shared.import.manifest"
    private let sharedTagsKey = "refma.shared.tags.json"

    private var shareItems: [ShareItem] = []
    private var sharedTags: [SharedTag] = []
    private var globalTagIds: Set<String> = []

    private let headerBlock = UIView()
    private let itemsTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let compressAllSwitch = UISwitch()
    private let addButton = UIButton(type: .system)
    private let tagsScrollView = UIScrollView()
    private let tagsStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSharedTags()
        loadShareItems()
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
                    let tagIds = tagIdsForProvider(provider)
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeImage, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "image", compress: compress, tagIds: tagIds) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeMovie) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeMovie, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "video", compress: false, tagIds: []) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeFileURL) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeFileURL, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false, tagIds: []) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeData) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeData, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false, tagIds: []) {
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
        textView.isHidden = true
        textView.isEditable = false
        textView.isUserInteractionEnabled = false
        textView.heightAnchor.constraint(equalToConstant: 0).isActive = true

        view.backgroundColor = .systemGroupedBackground

        headerBlock.translatesAutoresizingMaskIntoConstraints = false
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "Compress all"
        headerLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        headerLabel.textColor = .label

        compressAllSwitch.translatesAutoresizingMaskIntoConstraints = false
        compressAllSwitch.isOn = true
        compressAllSwitch.addTarget(self, action: #selector(handleCompressAll), for: .valueChanged)

        let tagsLabel = UILabel()
        tagsLabel.translatesAutoresizingMaskIntoConstraints = false
        tagsLabel.text = "Tags"
        tagsLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        tagsLabel.textColor = .secondaryLabel

        tagsScrollView.translatesAutoresizingMaskIntoConstraints = false
        tagsScrollView.showsHorizontalScrollIndicator = false

        tagsStack.translatesAutoresizingMaskIntoConstraints = false
        tagsStack.axis = .horizontal
        tagsStack.spacing = 8
        tagsStack.alignment = .center

        tagsScrollView.addSubview(tagsStack)
        headerBlock.addSubview(headerLabel)
        headerBlock.addSubview(compressAllSwitch)
        headerBlock.addSubview(tagsLabel)
        headerBlock.addSubview(tagsScrollView)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor, constant: 16),
            headerLabel.topAnchor.constraint(equalTo: headerBlock.topAnchor, constant: 12),

            compressAllSwitch.trailingAnchor.constraint(equalTo: headerBlock.trailingAnchor, constant: -16),
            compressAllSwitch.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),

            tagsLabel.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor, constant: 16),
            tagsLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),

            tagsScrollView.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor),
            tagsScrollView.trailingAnchor.constraint(equalTo: headerBlock.trailingAnchor),
            tagsScrollView.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 6),
            tagsScrollView.heightAnchor.constraint(equalToConstant: 34),
            tagsScrollView.bottomAnchor.constraint(equalTo: headerBlock.bottomAnchor, constant: -12),

            tagsStack.leadingAnchor.constraint(equalTo: tagsScrollView.leadingAnchor, constant: 16),
            tagsStack.trailingAnchor.constraint(equalTo: tagsScrollView.trailingAnchor, constant: -16),
            tagsStack.topAnchor.constraint(equalTo: tagsScrollView.topAnchor),
            tagsStack.bottomAnchor.constraint(equalTo: tagsScrollView.bottomAnchor),
            tagsStack.heightAnchor.constraint(equalTo: tagsScrollView.heightAnchor)
        ])

        itemsTableView.translatesAutoresizingMaskIntoConstraints = false
        itemsTableView.dataSource = self
        itemsTableView.delegate = self
        itemsTableView.rowHeight = UITableView.automaticDimension
        itemsTableView.estimatedRowHeight = 110
        itemsTableView.tableFooterView = UIView()
        itemsTableView.separatorStyle = .none
        itemsTableView.backgroundColor = .clear
        itemsTableView.register(ShareItemCell.self, forCellReuseIdentifier: ShareItemCell.reuseId)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("Add photo", for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        addButton.backgroundColor = UIColor(red: 35.0/255.0, green: 107.0/255.0, blue: 166.0/255.0, alpha: 1.0)
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 10
        addButton.addTarget(self, action: #selector(handleAdd), for: .touchUpInside)

        view.addSubview(headerBlock)
        view.addSubview(itemsTableView)
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            headerBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            itemsTableView.topAnchor.constraint(equalTo: headerBlock.bottomAnchor, constant: 8),
            itemsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            itemsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            itemsTableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            addButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func loadSharedTags() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let json = defaults.string(forKey: sharedTagsKey),
              let data = json.data(using: .utf8) else {
            sharedTags = []
            reloadTagChips()
            return
        }

        do {
            let payload = try JSONSerialization.jsonObject(with: data, options: [])
            if let items = payload as? [[String: Any]] {
                sharedTags = items.compactMap { item -> SharedTag? in
                    guard let id = item["id"] as? String,
                          let name = item["name"] as? String else { return nil }
                    let colorValue = (item["colorValue"] as? Int) ?? 0xFF777777
                    return SharedTag(id: id, name: name, colorValue: colorValue)
                }
            }
        } catch {
            sharedTags = []
        }
        reloadTagChips()
    }

    private func reloadTagChips() {
        tagsStack.arrangedSubviews.forEach { view in
            tagsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for tag in sharedTags {
            let selected = globalTagIds.contains(tag.id)
            let chip = TagChipButton(tag: tag, selected: selected)
            chip.addTarget(self, action: #selector(handleGlobalTagTap(_:)), for: .touchUpInside)
            tagsStack.addArrangedSubview(chip)
        }
    }

    private func loadShareItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        let typeImage = kUTTypeImage as String
        var collected: [ShareItem] = []

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers where provider.hasItemConformingToTypeIdentifier(typeImage) {
                collected.append(ShareItem(provider: provider, typeIdentifier: typeImage, compress: true))
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

            DispatchQueue.main.async {
                item.thumbnail = image
                self.itemsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        }
    }

    private func updateCompressAllSwitch() {
        let allOn = !shareItems.isEmpty && shareItems.allSatisfy { $0.compress }
        compressAllSwitch.isOn = allOn
    }

    private func compressSetting(for provider: NSItemProvider) -> Bool {
        for item in shareItems where item.provider === provider {
            return item.compress
        }
        return compressAllSwitch.isOn
    }

    private func tagIdsForProvider(_ provider: NSItemProvider) -> [String] {
        for item in shareItems where item.provider === provider {
            return Array(item.selectedTagIds)
        }
        return Array(globalTagIds)
    }

    @objc private func handleCompressAll() {
        for item in shareItems {
            item.compress = compressAllSwitch.isOn
        }
        itemsTableView.reloadData()
    }

    @objc private func handleGlobalTagTap(_ sender: TagChipButton) {
        let tag = sender.tagModel
        if globalTagIds.contains(tag.id) {
            globalTagIds.remove(tag.id)
            for item in shareItems {
                item.selectedTagIds.remove(tag.id)
            }
        } else {
            globalTagIds.insert(tag.id)
            for item in shareItems {
                item.selectedTagIds.insert(tag.id)
            }
        }
        reloadTagChips()
        itemsTableView.reloadData()
    }

    @objc private func handleAdd() {
        addButton.isEnabled = false
        addButton.alpha = 0.6
        didSelectPost()
    }

    // MARK: Temporary storage

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

    private func handleLoadedItem(_ item: NSSecureCoding?, mediaTypeHint: String?, compress: Bool, tagIds: [String]) -> [String: Any]? {
        if let url = item as? URL {
            return copyFile(from: url, mediaTypeHint: mediaTypeHint, compress: compress, tagIds: tagIds)
        }
        if let image = item as? UIImage {
            guard let data = image.pngData() else { return nil }
            return writeData(data, ext: "png", originalName: "shared.png", mediaType: "image", compress: compress, tagIds: tagIds)
        }
        if let data = item as? Data {
            if mediaTypeHint == "image" {
                let ext = inferImageExtension(from: data)
                let name = ext.isEmpty ? "shared" : "shared.\(ext)"
                return writeData(data, ext: ext.isEmpty ? "img" : ext, originalName: name, mediaType: "image", compress: compress, tagIds: tagIds)
            }
            return writeData(data, ext: "bin", originalName: "shared.bin", mediaType: mediaTypeHint ?? "file", compress: compress, tagIds: tagIds)
        }
        return nil
    }

    private func copyFile(from url: URL, mediaTypeHint: String?, compress: Bool, tagIds: [String]) -> [String: Any]? {
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
            "compress": compress,
            "tagIds": tagIds,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    private func writeData(_ data: Data, ext: String, originalName: String, mediaType: String, compress: Bool, tagIds: [String]) -> [String: Any]? {
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
            "tagIds": tagIds,
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

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shareItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareItemCell.reuseId, for: indexPath) as? ShareItemCell else {
            return UITableViewCell()
        }
        let item = shareItems[indexPath.row]
        let selectedTags = sharedTags.filter { item.selectedTagIds.contains($0.id) }

        cell.configure(
            thumbnail: item.thumbnail,
            compress: item.compress,
            selectedTags: selectedTags,
            onToggleCompress: { [weak self] isOn in
                guard let self = self else { return }
                item.compress = isOn
                self.updateCompressAllSwitch()
            },
            onRemoveTag: { [weak self] tag in
                guard let self = self else { return }
                item.selectedTagIds.remove(tag.id)
                self.globalTagIds = self.shareItems.reduce(item.selectedTagIds) { result, next in
                    result.intersection(next.selectedTagIds)
                }
                self.reloadTagChips()
                self.itemsTableView.reloadRows(at: [indexPath], with: .none)
            }
        )
        return cell
    }
}
