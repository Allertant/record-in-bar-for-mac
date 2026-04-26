import SwiftUI
import Combine

@MainActor
public final class PopoverPinManager: ObservableObject {
    public static let shared = PopoverPinManager()
    @Published public var isPinned = false
    
    private init() {}
}
