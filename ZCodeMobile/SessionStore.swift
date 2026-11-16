import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [RemoteSession] = [] {
        didSet { persist() }
    }

    private let storageKey = "zcode.mobile.sessions.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([RemoteSession].self, from: data) {
            sessions = list
        }
    }

    func add(_ session: RemoteSession) {
        // 同一台设备（mid 相同）更新链接而非新增会话
        if let mid = session.machineID,
           let idx = sessions.firstIndex(where: { $0.machineID == mid }) {
            sessions[idx] = session
        } else if let idx = sessions.firstIndex(where: { $0.urlString == session.urlString }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
    }

    func remove(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
    }

    func touch(_ session: RemoteSession) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[idx].lastOpenedAt = Date()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
