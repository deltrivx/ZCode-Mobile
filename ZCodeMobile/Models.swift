import Foundation

/// 一个已保存的桌面客户端连接（对应一条 /remote/v4 链接）
struct RemoteSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var urlString: String
    var machineID: String?
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
}

/// 解析 ZCode「移动远程控制」链接：
/// https://zcode.z.ai/remote/v4?sid=..&mid=..&name=..&app_version=..
enum LinkParser {
    static func parse(_ raw: String) -> RemoteSession? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: trimmed),
              comps.path.contains("/remote/") else { return nil }
        if comps.scheme == nil { comps.scheme = "https" }
        guard let url = comps.url else { return nil }
        let items = comps.queryItems ?? []
        let name = items.first(where: { $0.name == "name" })?.value ?? "未命名设备"
        let mid = items.first(where: { $0.name == "mid" })?.value
        return RemoteSession(name: name, urlString: url.absoluteString, machineID: mid)
    }
}
