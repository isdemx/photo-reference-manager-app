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
    let categoryId: String?
    let categoryName: String?
}

final class ShareItem {
    let provider: NSItemProvider
    let typeIdentifier: String
    var thumbnail: UIImage?
    var compress: Bool
    var selectedTagIds: Set<String>
    var isExpanded: Bool
    var comment: String

    init(provider: NSItemProvider, typeIdentifier: String, compress: Bool) {
        self.provider = provider
        self.typeIdentifier = typeIdentifier
        self.compress = compress
        self.selectedTagIds = []
        self.isExpanded = false
        self.comment = ""
    }
}

final class TagChipButton: UIButton {
    let tagModel: SharedTag

    init(tag: SharedTag, selected: Bool) {
        self.tagModel = tag
        super.init(frame: .zero)
        setTitle(tag.name, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        setTitleColor(.white, for: .normal)
        backgroundColor = TagChipButton.colorFromFlutter(tag.colorValue)
            .withAlphaComponent(selected ? 1.0 : 0.4)
        layer.cornerRadius = 12
        contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
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

final class TagChipWrapCell: UICollectionViewCell {
    static let reuseId = "TagChipWrapCell"

    private let chipButton = TagChipButton(
        tag: SharedTag(id: "", name: "", colorValue: 0, categoryId: nil, categoryName: nil),
        selected: false
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(chipButton)
        chipButton.isUserInteractionEnabled = false
        chipButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            chipButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chipButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chipButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            chipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(tag: SharedTag, selected: Bool) {
        chipButton.setTitle(tag.name, for: .normal)
        chipButton.backgroundColor = TagChipButton.colorFromFlutter(tag.colorValue)
            .withAlphaComponent(selected ? 1.0 : 0.4)
    }
}

final class TagCategoryHeaderView: UICollectionReusableView {
    static let reuseId = "TagCategoryHeaderView"

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GroupedTagsView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collectionView: UICollectionView
    private var sections: [(String, [SharedTag])] = []
    private var selectedIds: Set<String> = []

    var onTapTag: ((SharedTag) -> Void)?

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 6, left: 0, bottom: 14, right: 0)
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.headerReferenceSize = CGSize(width: 1, height: 18)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 6, left: 0, bottom: 14, right: 0)
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.headerReferenceSize = CGSize(width: 1, height: 18)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TagChipWrapCell.self, forCellWithReuseIdentifier: TagChipWrapCell.reuseId)
        collectionView.register(TagCategoryHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: TagCategoryHeaderView.reuseId)

        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func update(tags: [SharedTag], selectedIds: Set<String>) {
        self.selectedIds = selectedIds
        let grouped = Dictionary(grouping: tags) { tag -> String in
            return tag.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? tag.categoryName!
                : "Other"
        }
        let sortedCategories = grouped.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        sections = sortedCategories.compactMap { key in
            guard let tags = grouped[key] else { return nil }
            return (key, tags)
        }
        collectionView.reloadData()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].1.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TagChipWrapCell.reuseId, for: indexPath) as? TagChipWrapCell else {
            return UICollectionViewCell()
        }
        let tag = sections[indexPath.section].1[indexPath.item]
        cell.configure(tag: tag, selected: selectedIds.contains(tag.id))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tag = sections[indexPath.section].1[indexPath.item]
        onTapTag?(tag)
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: TagCategoryHeaderView.reuseId,
                for: indexPath
              ) as? TagCategoryHeaderView else {
            return UICollectionReusableView()
        }
        header.label.text = sections[indexPath.section].0
        return header
    }
}

final class ShareItemCell: UITableViewCell, UITextViewDelegate {
    static let reuseId = "ShareItemCell"

    private let thumbImageView = UIImageView()
    private var thumbWidthConstraint: NSLayoutConstraint?
    private var thumbHeightConstraint: NSLayoutConstraint?
    private let compressLabel = UILabel()
    private let compressSwitch = UISwitch()
    private let commentTextView = UITextView()
    private let commentPlaceholder = UILabel()
    private let selectedTagsScrollView = UIScrollView()
    private let selectedTagsStack = UIStackView()

    private var onToggleCompress: ((Bool) -> Void)?
    private var onRemoveTag: ((SharedTag) -> Void)?
    private var onCommentChanged: ((String) -> Void)?

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

        commentTextView.translatesAutoresizingMaskIntoConstraints = false
        commentTextView.font = UIFont.systemFont(ofSize: 13)
        commentTextView.textColor = .label
        commentTextView.backgroundColor = .tertiarySystemBackground
        commentTextView.layer.cornerRadius = 8
        commentTextView.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        commentTextView.delegate = self

        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        commentPlaceholder.text = "Comment"
        commentPlaceholder.font = UIFont.systemFont(ofSize: 12)
        commentPlaceholder.textColor = .tertiaryLabel

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
        contentView.addSubview(commentTextView)
        commentTextView.addSubview(commentPlaceholder)
        contentView.addSubview(selectedTagsScrollView)

        thumbWidthConstraint = thumbImageView.widthAnchor.constraint(equalToConstant: 126)
        thumbHeightConstraint = thumbImageView.heightAnchor.constraint(equalToConstant: 126)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            thumbWidthConstraint!,
            thumbHeightConstraint!,

            compressSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            compressSwitch.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),

            compressLabel.trailingAnchor.constraint(equalTo: compressSwitch.leadingAnchor, constant: -8),
            compressLabel.centerYAnchor.constraint(equalTo: compressSwitch.centerYAnchor),

            commentTextView.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            commentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            commentTextView.topAnchor.constraint(equalTo: compressSwitch.bottomAnchor, constant: 8),
            commentTextView.heightAnchor.constraint(equalToConstant: 54),

            commentPlaceholder.leadingAnchor.constraint(equalTo: commentTextView.leadingAnchor, constant: 10),
            commentPlaceholder.topAnchor.constraint(equalTo: commentTextView.topAnchor, constant: 6),

            selectedTagsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectedTagsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectedTagsScrollView.topAnchor.constraint(equalTo: commentTextView.bottomAnchor, constant: 8),
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
        isExpanded: Bool,
        comment: String,
        selectedTags: [SharedTag],
        onToggleCompress: @escaping (Bool) -> Void,
        onRemoveTag: @escaping (SharedTag) -> Void,
        onCommentChanged: @escaping (String) -> Void
    ) {
        thumbImageView.image = thumbnail ?? UIImage(systemName: "photo")
        compressSwitch.isOn = compress
        self.onToggleCompress = onToggleCompress
        self.onRemoveTag = onRemoveTag
        self.onCommentChanged = onCommentChanged
        let size: CGFloat = isExpanded ? 189 : 126
        thumbWidthConstraint?.constant = size
        thumbHeightConstraint?.constant = size
        commentTextView.text = comment
        commentPlaceholder.isHidden = !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        selectedTagsStack.arrangedSubviews.forEach { view in
            selectedTagsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if selectedTags.isEmpty {
            let placeholder = UILabel()
            placeholder.text = ""
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

    func textViewDidChange(_ textView: UITextView) {
        let text = textView.text ?? ""
        commentPlaceholder.isHidden = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        onCommentChanged?(text)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCommentChanged = nil
        onToggleCompress = nil
        onRemoveTag = nil
        commentTextView.text = ""
        commentPlaceholder.isHidden = false
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
    private let compressAllContainer = UIView()
    private let itemsTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let wrapTagsContainer = UIView()
    private let wrapTagsLabel = UILabel()
    private let wrapTagsView = GroupedTagsView()
    private let compressAllSwitch = UISwitch()
    private let addButton = UIButton(type: .system)
    private let tagsScrollView = UIScrollView()
    private let tagsStack = UIStackView()
    private let tagsToggleButton = UIButton(type: .system)

    private let tagsOverlayView = UIView()
    private let tagsOverlayPanel = UIView()
    private let tagsOverlayHeader = UIView()
    private let tagsOverlayTitle = UILabel()
    private let tagsOverlayCloseButton = UIButton(type: .system)
    private let tagsOverlayViewContent = GroupedTagsView()

    private var tagsTopToCompressConstraint: NSLayoutConstraint?
    private var tagsTopToHeaderConstraint: NSLayoutConstraint?
    private var itemsTableTopToHeaderConstraint: NSLayoutConstraint?
    private var itemsTableTopToSafeConstraint: NSLayoutConstraint?
    private var itemsTableBottomToWrapConstraint: NSLayoutConstraint?
    private var itemsTableBottomToAddConstraint: NSLayoutConstraint?
    private var wrapTagsHeightConstraint: NSLayoutConstraint?
    private var itemsTableFixedHeightConstraint: NSLayoutConstraint?

    override func loadView() {
        view = UIView()
    }

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
                    let comment = commentForProvider(provider)
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeImage, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "image", compress: compress, tagIds: tagIds, comment: comment) {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeMovie) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeMovie, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: "video", compress: false, tagIds: [], comment: "") {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeFileURL) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeFileURL, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false, tagIds: [], comment: "") {
                            manifestQueue.sync { newEntries.append(entry) }
                        }
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(typeData) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: typeData, options: nil) { data, _ in
                        defer { group.leave() }
                        if let entry = self.handleLoadedItem(data, mediaTypeHint: nil, compress: false, tagIds: [], comment: "") {
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

        view.backgroundColor = .systemGroupedBackground
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleEndEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        headerBlock.translatesAutoresizingMaskIntoConstraints = false
        compressAllContainer.translatesAutoresizingMaskIntoConstraints = false

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

        tagsToggleButton.translatesAutoresizingMaskIntoConstraints = false
        tagsToggleButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        tagsToggleButton.tintColor = .secondaryLabel
        tagsToggleButton.addTarget(self, action: #selector(handleShowAllTags), for: .touchUpInside)

        tagsScrollView.translatesAutoresizingMaskIntoConstraints = false
        tagsScrollView.showsHorizontalScrollIndicator = false

        tagsStack.translatesAutoresizingMaskIntoConstraints = false
        tagsStack.axis = .horizontal
        tagsStack.spacing = 8
        tagsStack.alignment = .center

        tagsScrollView.addSubview(tagsStack)
        compressAllContainer.addSubview(headerLabel)
        compressAllContainer.addSubview(compressAllSwitch)
        headerBlock.addSubview(compressAllContainer)
        headerBlock.addSubview(tagsLabel)
        headerBlock.addSubview(tagsToggleButton)
        headerBlock.addSubview(tagsScrollView)

        tagsTopToCompressConstraint = tagsLabel.topAnchor.constraint(equalTo: compressAllContainer.bottomAnchor, constant: 38)
        tagsTopToHeaderConstraint = tagsLabel.topAnchor.constraint(equalTo: headerBlock.topAnchor, constant: 22)
        tagsTopToCompressConstraint?.isActive = true

        NSLayoutConstraint.activate([
            compressAllContainer.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor, constant: 16),
            compressAllContainer.trailingAnchor.constraint(equalTo: headerBlock.trailingAnchor, constant: -16),
            compressAllContainer.topAnchor.constraint(equalTo: headerBlock.topAnchor, constant: 32),

            headerLabel.leadingAnchor.constraint(equalTo: compressAllContainer.leadingAnchor),
            headerLabel.topAnchor.constraint(equalTo: compressAllContainer.topAnchor),
            headerLabel.bottomAnchor.constraint(equalTo: compressAllContainer.bottomAnchor),

            compressAllSwitch.trailingAnchor.constraint(equalTo: compressAllContainer.trailingAnchor),
            compressAllSwitch.centerYAnchor.constraint(equalTo: compressAllContainer.centerYAnchor),

            tagsLabel.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor, constant: 16),

            tagsToggleButton.trailingAnchor.constraint(equalTo: headerBlock.trailingAnchor, constant: -16),
            tagsToggleButton.centerYAnchor.constraint(equalTo: tagsLabel.centerYAnchor),
            tagsToggleButton.widthAnchor.constraint(equalToConstant: 28),
            tagsToggleButton.heightAnchor.constraint(equalToConstant: 28),

            tagsScrollView.leadingAnchor.constraint(equalTo: headerBlock.leadingAnchor),
            tagsScrollView.trailingAnchor.constraint(equalTo: headerBlock.trailingAnchor),
            tagsScrollView.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 12),
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

        wrapTagsContainer.translatesAutoresizingMaskIntoConstraints = false
        wrapTagsContainer.backgroundColor = .secondarySystemBackground
        wrapTagsContainer.layer.cornerRadius = 12
        wrapTagsContainer.layer.masksToBounds = true

        wrapTagsLabel.translatesAutoresizingMaskIntoConstraints = false
        wrapTagsLabel.text = "All tags"
        wrapTagsLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        wrapTagsLabel.textColor = .secondaryLabel

        wrapTagsContainer.addSubview(wrapTagsLabel)
        wrapTagsContainer.addSubview(wrapTagsView)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("Add photo", for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        addButton.backgroundColor = UIColor(red: 35.0/255.0, green: 107.0/255.0, blue: 166.0/255.0, alpha: 1.0)
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 10
        addButton.addTarget(self, action: #selector(handleAdd), for: .touchUpInside)

        view.addSubview(headerBlock)
        view.addSubview(itemsTableView)
        view.addSubview(wrapTagsContainer)
        view.addSubview(addButton)
        setupTagsOverlay()

        itemsTableTopToHeaderConstraint = itemsTableView.topAnchor.constraint(equalTo: headerBlock.bottomAnchor, constant: 8)
        itemsTableTopToSafeConstraint = itemsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        itemsTableBottomToWrapConstraint = itemsTableView.bottomAnchor.constraint(equalTo: wrapTagsContainer.topAnchor, constant: -8)
        itemsTableBottomToAddConstraint = itemsTableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8)
        wrapTagsHeightConstraint = wrapTagsContainer.heightAnchor.constraint(equalToConstant: 0)
        itemsTableFixedHeightConstraint = itemsTableView.heightAnchor.constraint(equalToConstant: 220)

        itemsTableTopToHeaderConstraint?.isActive = true
        itemsTableBottomToWrapConstraint?.isActive = true

        NSLayoutConstraint.activate([
            headerBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            itemsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            itemsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            wrapTagsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wrapTagsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            wrapTagsContainer.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            wrapTagsLabel.leadingAnchor.constraint(equalTo: wrapTagsContainer.leadingAnchor, constant: 12),
            wrapTagsLabel.topAnchor.constraint(equalTo: wrapTagsContainer.topAnchor, constant: 8),

            wrapTagsView.leadingAnchor.constraint(equalTo: wrapTagsContainer.leadingAnchor, constant: 12),
            wrapTagsView.trailingAnchor.constraint(equalTo: wrapTagsContainer.trailingAnchor, constant: -12),
            wrapTagsView.topAnchor.constraint(equalTo: wrapTagsLabel.bottomAnchor, constant: 8),
            wrapTagsView.bottomAnchor.constraint(equalTo: wrapTagsContainer.bottomAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            addButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupTagsOverlay() {
        tagsOverlayView.translatesAutoresizingMaskIntoConstraints = false
        tagsOverlayView.backgroundColor = .clear
        tagsOverlayView.isHidden = true

        tagsOverlayPanel.translatesAutoresizingMaskIntoConstraints = false
        tagsOverlayPanel.backgroundColor = .systemGroupedBackground
        tagsOverlayPanel.layer.cornerRadius = 16
        tagsOverlayPanel.layer.masksToBounds = true

        tagsOverlayHeader.translatesAutoresizingMaskIntoConstraints = false

        tagsOverlayTitle.translatesAutoresizingMaskIntoConstraints = false
        tagsOverlayTitle.text = "Tags"
        tagsOverlayTitle.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        tagsOverlayTitle.textColor = .label
        tagsOverlayTitle.textAlignment = .center

        tagsOverlayCloseButton.translatesAutoresizingMaskIntoConstraints = false
        tagsOverlayCloseButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        tagsOverlayCloseButton.tintColor = .secondaryLabel
        tagsOverlayCloseButton.addTarget(self, action: #selector(handleCloseAllTags), for: .touchUpInside)

        tagsOverlayHeader.addSubview(tagsOverlayTitle)
        tagsOverlayHeader.addSubview(tagsOverlayCloseButton)
        tagsOverlayPanel.addSubview(tagsOverlayHeader)
        tagsOverlayPanel.addSubview(tagsOverlayViewContent)
        tagsOverlayView.addSubview(tagsOverlayPanel)
        view.addSubview(tagsOverlayView)

        NSLayoutConstraint.activate([
            tagsOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            tagsOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tagsOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tagsOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tagsOverlayPanel.topAnchor.constraint(equalTo: tagsOverlayView.safeAreaLayoutGuide.topAnchor, constant: 30),
            tagsOverlayPanel.leadingAnchor.constraint(equalTo: tagsOverlayView.leadingAnchor, constant: 10),
            tagsOverlayPanel.trailingAnchor.constraint(equalTo: tagsOverlayView.trailingAnchor, constant: -10),
            tagsOverlayPanel.bottomAnchor.constraint(equalTo: tagsOverlayView.bottomAnchor, constant: -30),

            tagsOverlayHeader.topAnchor.constraint(equalTo: tagsOverlayPanel.topAnchor),
            tagsOverlayHeader.leadingAnchor.constraint(equalTo: tagsOverlayPanel.leadingAnchor),
            tagsOverlayHeader.trailingAnchor.constraint(equalTo: tagsOverlayPanel.trailingAnchor),
            tagsOverlayHeader.heightAnchor.constraint(equalToConstant: 52),

            tagsOverlayTitle.centerXAnchor.constraint(equalTo: tagsOverlayHeader.centerXAnchor),
            tagsOverlayTitle.centerYAnchor.constraint(equalTo: tagsOverlayHeader.centerYAnchor),

            tagsOverlayCloseButton.trailingAnchor.constraint(equalTo: tagsOverlayHeader.trailingAnchor, constant: -16),
            tagsOverlayCloseButton.centerYAnchor.constraint(equalTo: tagsOverlayHeader.centerYAnchor),
            tagsOverlayCloseButton.widthAnchor.constraint(equalToConstant: 28),
            tagsOverlayCloseButton.heightAnchor.constraint(equalToConstant: 28),

            tagsOverlayViewContent.leadingAnchor.constraint(equalTo: tagsOverlayPanel.leadingAnchor, constant: 16),
            tagsOverlayViewContent.trailingAnchor.constraint(equalTo: tagsOverlayPanel.trailingAnchor, constant: -16),
            tagsOverlayViewContent.topAnchor.constraint(equalTo: tagsOverlayHeader.bottomAnchor),
            tagsOverlayViewContent.bottomAnchor.constraint(equalTo: tagsOverlayPanel.bottomAnchor)
        ])
    }

    @objc private func handleEndEditing() {
        view.endEditing(true)
    }

    private func loadSharedTags() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let json = defaults.string(forKey: sharedTagsKey),
              let data = json.data(using: .utf8) else {
            sharedTags = []
            reloadTagChips()
            updateGroupedTagViews()
            return
        }

        do {
            let payload = try JSONSerialization.jsonObject(with: data, options: [])
            if let items = payload as? [[String: Any]] {
                sharedTags = items.compactMap { item -> SharedTag? in
                    guard let id = item["id"] as? String,
                          let name = item["name"] as? String else { return nil }
                    let colorValue = (item["colorValue"] as? Int) ?? 0xFF777777
                    let categoryId = item["tagCategoryId"] as? String
                    let categoryName = item["tagCategoryName"] as? String
                    return SharedTag(
                        id: id,
                        name: name,
                        colorValue: colorValue,
                        categoryId: categoryId,
                        categoryName: categoryName
                    )
                }
            }
        } catch {
            sharedTags = []
        }
        reloadTagChips()
        updateGroupedTagViews()
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

    private func updateGroupedTagViews() {
        wrapTagsView.onTapTag = { [weak self] tag in
            guard let self = self else { return }
            self.toggleGlobalTag(tag)
            self.reloadTagChips()
            self.updateGroupedTagViews()
            self.itemsTableView.reloadData()
        }
        tagsOverlayViewContent.onTapTag = wrapTagsView.onTapTag
        wrapTagsView.update(tags: sharedTags, selectedIds: globalTagIds)
        tagsOverlayViewContent.update(tags: sharedTags, selectedIds: globalTagIds)
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
        updateLayoutForItems()
        updateAddButtonTitle()
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
                let typeImage = kUTTypeImage as String
                if item.provider.hasItemConformingToTypeIdentifier(typeImage) {
                    item.provider.loadItem(forTypeIdentifier: typeImage, options: nil) { data, _ in
                        let fallback = self.imageFromItem(data)
                        DispatchQueue.main.async {
                            item.thumbnail = fallback
                            self.itemsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        }
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                item.thumbnail = image
                self.itemsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        }
    }

    private func imageFromItem(_ item: NSSecureCoding?) -> UIImage? {
        if let uiImage = item as? UIImage {
            return uiImage
        }
        if let url = item as? URL {
            return UIImage(contentsOfFile: url.path)
        }
        if let data = item as? Data {
            return UIImage(data: data)
        }
        return nil
    }

    private func updateCompressAllSwitch() {
        let allOn = !shareItems.isEmpty && shareItems.allSatisfy { $0.compress }
        compressAllSwitch.isOn = allOn
    }

    private func updateLayoutForItems() {
        let hasMultiple = shareItems.count > 1
        let showCompressAll = shareItems.count > 1
        compressAllContainer.isHidden = !showCompressAll
            tagsTopToCompressConstraint?.isActive = showCompressAll
            tagsTopToHeaderConstraint?.isActive = !showCompressAll

        headerBlock.isHidden = !hasMultiple
        wrapTagsContainer.isHidden = hasMultiple

        itemsTableTopToHeaderConstraint?.isActive = hasMultiple
        itemsTableTopToSafeConstraint?.isActive = !hasMultiple

        itemsTableBottomToWrapConstraint?.isActive = !hasMultiple
        itemsTableBottomToAddConstraint?.isActive = hasMultiple

        wrapTagsHeightConstraint?.isActive = hasMultiple
        itemsTableFixedHeightConstraint?.isActive = !hasMultiple
    }

    private func updateAddButtonTitle() {
        let title = shareItems.count > 1 ? "Add photos" : "Add photo"
        addButton.setTitle(title, for: .normal)
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

    private func commentForProvider(_ provider: NSItemProvider) -> String {
        for item in shareItems where item.provider === provider {
            return item.comment
        }
        return ""
    }

    private func toggleGlobalTag(_ tag: SharedTag) {
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
    }

    @objc private func handleCompressAll() {
        for item in shareItems {
            item.compress = compressAllSwitch.isOn
        }
        itemsTableView.reloadData()
    }

    @objc private func handleGlobalTagTap(_ sender: TagChipButton) {
        let tag = sender.tagModel
        toggleGlobalTag(tag)
        reloadTagChips()
        updateGroupedTagViews()
        itemsTableView.reloadData()
    }

    @objc private func handleShowAllTags() {
        tagsOverlayView.isHidden = false
        view.bringSubviewToFront(tagsOverlayView)
    }

    @objc private func handleCloseAllTags() {
        tagsOverlayView.isHidden = true
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

    private func handleLoadedItem(_ item: NSSecureCoding?, mediaTypeHint: String?, compress: Bool, tagIds: [String], comment: String) -> [String: Any]? {
        if let url = item as? URL {
            return copyFile(from: url, mediaTypeHint: mediaTypeHint, compress: compress, tagIds: tagIds, comment: comment)
        }
        if let image = item as? UIImage {
            guard let data = image.pngData() else { return nil }
            return writeData(data, ext: "png", originalName: "shared.png", mediaType: "image", compress: compress, tagIds: tagIds, comment: comment)
        }
        if let data = item as? Data {
            if mediaTypeHint == "image" {
                let ext = inferImageExtension(from: data)
                let name = ext.isEmpty ? "shared" : "shared.\(ext)"
                return writeData(data, ext: ext.isEmpty ? "img" : ext, originalName: name, mediaType: "image", compress: compress, tagIds: tagIds, comment: comment)
            }
            return writeData(data, ext: "bin", originalName: "shared.bin", mediaType: mediaTypeHint ?? "file", compress: compress, tagIds: tagIds, comment: comment)
        }
        return nil
    }

    private func copyFile(from url: URL, mediaTypeHint: String?, compress: Bool, tagIds: [String], comment: String) -> [String: Any]? {
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
            "comment": comment,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    private func writeData(_ data: Data, ext: String, originalName: String, mediaType: String, compress: Bool, tagIds: [String], comment: String) -> [String: Any]? {
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
            "comment": comment,
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
            isExpanded: item.isExpanded,
            comment: item.comment,
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
                self.updateGroupedTagViews()
                self.itemsTableView.reloadRows(at: [indexPath], with: .none)
            },
            onCommentChanged: { text in
                item.comment = text
            }
        )
        return cell
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shareItems[indexPath.row].isExpanded.toggle()
        tableView.beginUpdates()
        tableView.reloadRows(at: [indexPath], with: .none)
        tableView.endUpdates()
    }

    // MARK: -
}
