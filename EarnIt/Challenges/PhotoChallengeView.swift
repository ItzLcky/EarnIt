import SwiftUI
import Vision
import UIKit

/// Something to photograph, plus the Vision classifier labels that count as a match.
struct PhotoTarget: Identifiable, Equatable {
    let id: String
    let prompt: String
    let emoji: String
    let keywords: [String]

    static let all: [PhotoTarget] = [
        .init(id: "plant", prompt: "a plant or flower", emoji: "🪴", keywords: ["plant", "flower", "tree", "leaf", "foliage", "blossom"]),
        .init(id: "sky", prompt: "the sky (go outside!)", emoji: "☁️", keywords: ["sky", "cloud", "sunset", "sunrise"]),
        .init(id: "cup", prompt: "a cup or mug", emoji: "☕️", keywords: ["cup", "mug", "coffee", "tea"]),
        .init(id: "book", prompt: "a book", emoji: "📚", keywords: ["book", "publication", "magazine"]),
        .init(id: "shoes", prompt: "your shoes", emoji: "👟", keywords: ["shoe", "footwear", "sneaker", "boot", "sandal"]),
        .init(id: "fruit", prompt: "a piece of fruit", emoji: "🍎", keywords: ["fruit", "apple", "banana", "orange", "citrus", "berry", "grape", "pear"]),
        .init(id: "water", prompt: "a glass or bottle of water", emoji: "💧", keywords: ["water", "bottle", "glass", "drink", "beverage"]),
        .init(id: "street", prompt: "a street, path or building outside", emoji: "🏙️", keywords: ["street", "road", "building", "sidewalk", "path", "house", "structure", "outdoor"]),
    ]

    static func random(_ n: Int) -> [PhotoTarget] { Array(all.shuffled().prefix(n)) }
}

struct PhotoChallengeView: View {
    let count: Int
    let onComplete: () -> Void

    @State private var targets: [PhotoTarget] = []
    @State private var index = 0
    @State private var showCamera = false
    @State private var checking = false
    @State private var feedback: String?
    @State private var rerolls = 2

    private var current: PhotoTarget? { targets.indices.contains(index) ? targets[index] : nil }

    var body: some View {
        VStack(spacing: 20) {
            if count > 1 {
                Text("Photo \(index + 1) of \(count)").font(.headline).foregroundStyle(.secondary)
            }
            Spacer()
            if let current {
                Text(current.emoji).font(.system(size: 96))
                Text("Take a photo of").font(.title3).foregroundStyle(.secondary)
                Text(current.prompt).font(.largeTitle.bold()).multilineTextAlignment(.center)
            }
            if let feedback {
                Text(feedback)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
            if checking {
                ProgressView("Checking your photo…")
            } else {
                Button {
                    showCamera = true
                } label: {
                    Label("Open camera", systemImage: "camera.fill")
                }
                .buttonStyle(.primary)
                if rerolls > 0 {
                    Button("Can't find one? Swap (\(rerolls) left)") { reroll() }
                        .foregroundStyle(.secondary)
                }
            }
            Text("Photos are checked on your device and never saved or uploaded.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(24)
        .onAppear { if targets.isEmpty { targets = PhotoTarget.random(count) } }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { check(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func reroll() {
        guard let current else { return }
        let used = Set(targets.map(\.id))
        if let replacement = PhotoTarget.all.filter({ !used.contains($0.id) }).randomElement() {
            targets[index] = replacement
        } else {
            targets[index] = PhotoTarget.all.filter { $0 != current }.randomElement() ?? current
        }
        rerolls -= 1
        feedback = nil
    }

    private func check(_ image: UIImage) {
        guard let target = current else { return }
        checking = true
        feedback = nil
        Task.detached(priority: .userInitiated) {
            let labels = ImageClassifier.labels(for: image)
            let matched = labels.contains { label in
                label.confidence >= 0.15 && target.keywords.contains { label.identifier.contains($0) }
            }
            await MainActor.run {
                checking = false
                if matched {
                    if index + 1 >= count {
                        onComplete()
                    } else {
                        index += 1
                        feedback = "✅ Nice! Next one."
                    }
                } else {
                    let seen = labels.prefix(3).map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                    feedback = seen.isEmpty
                        ? "Couldn't make that out. Try again with better light."
                        : "That looks like: \(seen.joined(separator: ", ")). Try again, get closer and fill the frame."
                }
            }
        }
    }
}

enum ImageClassifier {
    struct Result { let identifier: String; let confidence: Float }

    /// On-device classification using Apple's built-in Vision taxonomy (~1,300 labels). No network needed.
    static func labels(for image: UIImage) -> [Result] {
        guard let cg = image.cgImage else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? [])
            .filter { $0.confidence > 0.05 }
            .sorted { $0.confidence > $1.confidence }
            .map { Result(identifier: $0.identifier.lowercased(), confidence: $0.confidence) }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Live camera only, so no picking an old photo from the library.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
