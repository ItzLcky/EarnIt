import SwiftUI
import AVFoundation
import Vision

/// Front camera + Vision body pose → live rep count. Frames are processed in memory only.
final class PoseCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var reps = 0
    @Published var bodyVisible = false
    @Published var hint = "Getting ready…"
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "earnit.pose")
    private var counter: RepCounter
    private var configured = false

    init(kind: ChallengeKind) {
        counter = RepCounter(kind: kind)
        super.init()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    if ok { self.configureAndRun() } else { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    private func configureAndRun() {
        queue.async { [self] in
            if !configured {
                session.beginConfiguration()
                session.sessionPreset = .high
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device),
                      session.canAddInput(input) else {
                    session.commitConfiguration()
                    return
                }
                session.addInput(input)

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: queue)
                if session.canAddOutput(output) { session.addOutput(output) }
                if let conn = output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90 // deliver upright portrait frames
                }
                session.commitConfiguration()
                configured = true
            }
            session.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        var joints: [Joint: CGPoint] = [:]
        if let body = request.results?.first, let points = try? body.recognizedPoints(.all) {
            for (name, p) in points where p.confidence > 0.3 {
                // Scale to pixels so angles aren't distorted by the frame's aspect ratio.
                joints[name] = CGPoint(x: p.location.x * width, y: p.location.y * height)
            }
        }

        let update = counter.process(joints)
        DispatchQueue.main.async {
            self.bodyVisible = update.bodyVisible
            self.hint = update.hint
            if update.repCompleted {
                self.reps += 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

struct ExerciseChallengeView: View {
    let kind: ChallengeKind
    let goal: Int
    let onComplete: () -> Void

    @StateObject private var camera: PoseCamera
    @State private var finished = false

    init(kind: ChallengeKind, goal: Int, onComplete: @escaping () -> Void) {
        self.kind = kind
        self.goal = goal
        self.onComplete = onComplete
        _camera = StateObject(wrappedValue: PoseCamera(kind: kind))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Label(kind.title, systemImage: kind.systemImage).font(.headline)
                    Spacer()
                    Circle()
                        .fill(camera.bodyVisible ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(camera.bodyVisible ? "Tracking" : "No body")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding()

                Spacer()

                Text("\(camera.reps)")
                    .font(.system(size: 120, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring, value: camera.reps)
                Text("of \(goal)")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                ProgressView(value: min(1, Double(camera.reps) / Double(goal)))
                    .tint(.accentColor)
                    .padding(.horizontal, 40)
                Text(camera.hint)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
            }

            if camera.permissionDenied {
                VStack(spacing: 12) {
                    Text("Camera access needed").font(.title2.bold())
                    Text("EarnIt counts reps with the camera, on-device only. Enable it in Settings.")
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.primary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            camera.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            camera.stop()
        }
        .onChange(of: camera.reps) { _, n in
            if n >= goal && !finished {
                finished = true
                camera.stop()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
