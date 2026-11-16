import SwiftUI
import VisionKit
import AVFoundation

/// VisionKit 扫码封装（iOS 16+），识别到内容后回调原始字符串
struct ScanView: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(qrCode: true)],
            qualityAdjustmentMode: .auto,
            isHighlightingEnabled: true,
            isPinchToZoomEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (String) -> Void
        private var reported: Set<String> = []

        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd added: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for case let .barcode(barcode) in allItems {
                if let raw = barcode.payloadStringValue, !raw.isEmpty, !reported.contains(raw) {
                    reported.insert(raw)
                    onFound(raw)
                }
            }
        }
    }
}
