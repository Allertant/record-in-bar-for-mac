enum TopicKind: String, CaseIterable, Identifiable {
    case video
    case novel
    case article
    case podcast
    case idea
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video:
            "视频"
        case .novel:
            "小说"
        case .article:
            "文章"
        case .podcast:
            "播客"
        case .idea:
            "想法"
        case .other:
            "其他"
        }
    }
}
