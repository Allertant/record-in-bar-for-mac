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
            "Video"
        case .novel:
            "Novel"
        case .article:
            "Article"
        case .podcast:
            "Podcast"
        case .idea:
            "Idea"
        case .other:
            "Other"
        }
    }
}
