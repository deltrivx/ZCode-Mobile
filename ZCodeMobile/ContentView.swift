import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showScanner = false
    @State private var showManualInput = false

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("还没有连接").font(.headline)
                        Text("点击右上角 + 扫码或输入链接\n添加你的 ZCode 桌面客户端")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(store.sessions) { session in
                            NavigationLink(value: session) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.name).font(.headline)
                                    Text(session.urlString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                }
            }
            .navigationTitle("ZCode Mobile")
            .navigationDestination(for: RemoteSession.self) { session in
                SessionView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showScanner = true
                        } label: {
                            Label("扫码连接", systemImage: "qrcode.viewfinder")
                        }
                        Button {
                            showManualInput = true
                        } label: {
                            Label("输入链接", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showScanner) { ScannerSheet() }
            .sheet(isPresented: $showManualInput) { ManualInputSheet() }
        }
    }
}

/// 手动输入链接：Form 弹层替代 alert（alert 内 TextField 会竖向裁切文字）
struct ManualInputSheet: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://zcode.z.ai/remote/v4?sid=...",
                              text: $link,
                              axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.body.monospaced())
                } header: {
                    Text("桌面端「移动远程控制」面板复制的链接")
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                Section {
                    Button {
                        if let s = LinkParser.parse(link) {
                            store.add(s)
                            dismiss()
                        } else {
                            errorMessage = "无法识别：链接需要包含 /remote/ 路径"
                        }
                    } label: {
                        Text("添加连接")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("输入链接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct ScannerSheet: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var status = "对准桌面端弹出的二维码"
    @State private var cameraDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScanView { raw in
                    if let s = LinkParser.parse(raw) {
                        store.add(s)
                        status = "已添加：\(s.name)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    } else {
                        status = "不是 ZCode 连接二维码"
                    }
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Text(status)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("扫码连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { checkCamera() }
            .alert("无法访问相机", isPresented: $cameraDenied) {
                Button("好") { dismiss() }
            } message: {
                Text("请在系统设置中允许 ZCode Mobile 使用相机。")
            }
        }
    }

    private func checkCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        default:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                if !ok { cameraDenied = true }
            }
        }
    }
}
