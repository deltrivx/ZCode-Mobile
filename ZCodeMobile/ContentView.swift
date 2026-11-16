import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showScanner = false
    @State private var showManualInput = false
    @State private var manualLink = ""

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
            .alert("输入链接", isPresented: $showManualInput) {
                TextField("https://zcode.z.ai/remote/v4?...", text: $manualLink)
                Button("添加") {
                    if let s = LinkParser.parse(manualLink) { store.add(s) }
                    manualLink = ""
                }
                Button("取消", role: .cancel) { manualLink = "" }
            } message: {
                Text("粘贴桌面端「移动远程控制」面板复制的链接")
            }
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
