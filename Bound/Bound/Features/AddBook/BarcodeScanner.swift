import Foundation
import SwiftUI
import UIKit
import VisionKit

/// Live camera that reads the ISBN barcode on the back of a book and hands it back once.
struct BarcodeScanner: UIViewControllerRepresentable {
    let onISBN: (String) -> Void

    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],   // ISBN-13 barcodes are EAN-13
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onISBN: onISBN) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onISBN: (String) -> Void
        private var done = false

        init(onISBN: @escaping (String) -> Void) { self.onISBN = onISBN }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                // books start 978 / 979; skips price barcodes and the like
                if case .barcode(let code) = item, let value = code.payloadStringValue,
                   value.count == 13, value.hasPrefix("978") || value.hasPrefix("979") {
                    done = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onISBN(value)
                    return
                }
            }
        }
    }
}

/// Full-screen scanner with a frame and a close button, on theme.
struct ScanSheet: View {
    let onISBN: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if BarcodeScanner.isAvailable {
                BarcodeScanner { isbn in
                    onISBN(isbn)
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                Theme.Colors.ink.ignoresSafeArea()
                Text("The camera isn't available here.\nTry on a phone, or type the ISBN instead.")
                    .font(Theme.Fonts.body(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.card)
                    .padding(32)
            }
            VStack {
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(Theme.Fonts.letterpress(18))
                        .foregroundStyle(Theme.Colors.card)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Theme.Colors.ink.opacity(0.6))
                }
                .padding(16)
                Spacer()
                Text("Point at the barcode on the back cover")
                    .font(Theme.Fonts.letterpress(18))
                    .foregroundStyle(Theme.Colors.card)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Theme.Colors.ink.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
    }
}
