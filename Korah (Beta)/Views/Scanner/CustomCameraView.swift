import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera View Model

@MainActor
@Observable
class CameraViewModel: NSObject {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var isFlashOn = false
    var isSessionRunning = false
    var errorMessage: String?
    
    private var currentCamera: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    private let sessionQueue = DispatchQueue(label: "com.korah.camera.session", qos: .userInitiated)
    
    override init() {
        super.init()
    }
    
    func setupCamera() async throws {
        stopCamera()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Prefer 0.5x ultra-wide camera and fall back to other rear cameras
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        guard let camera =
            discovery.devices.first(where: { $0.deviceType == .builtInUltraWideCamera }) ??
            discovery.devices.first else {
            session.commitConfiguration()
            throw CameraError.noCameraAvailable
        }
        
        currentCamera = camera
        
        // Add camera input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        session.addOutput(output)
        
        photoOutput = output
        session.commitConfiguration()
        captureSession = session
        isFlashOn = false
        errorMessage = nil
        
        // Start session on dedicated queue and verify running state
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                
                if session.isRunning {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: CameraError.sessionStartFailed)
                }
            }
        }
        
        isSessionRunning = session.isRunning
    }
    
    func stopCamera() {
        if isFlashOn {
            setTorchEnabled(false)
        }
        
        guard let session = captureSession else {
            isSessionRunning = false
            return
        }
        
        captureSession = nil
        photoOutput = nil
        currentCamera = nil
        isSessionRunning = false
        
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        
        // Configure flash
        if photoOutput.supportedFlashModes.contains(.on) {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash() {
        setTorchEnabled(!isFlashOn)
    }
    
    private func setTorchEnabled(_ enabled: Bool) {
        guard let device = currentCamera, device.hasTorch else {
            isFlashOn = false
            if enabled {
                errorMessage = "Flash isn’t available on this camera."
            }
            return
        }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            if enabled {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            
            isFlashOn = enabled
        } catch {
            isFlashOn = false
            errorMessage = "Unable to change flash right now."
        }
    }
    
    enum CameraError: Error {
        case noCameraAvailable
        case configurationFailed
        case sessionStartFailed
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                photoCompletion?(nil)
                photoCompletion = nil
            }
            return
        }
        
        Task { @MainActor in
            photoCompletion?(image)
            photoCompletion = nil
        }
    }
}

// MARK: - Camera Preview Representable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Custom Camera View

struct CustomCameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = CameraViewModel()
    @State private var showPermissionAlert = false
    @State private var isCapturing = false
    @State private var setupTask: Task<Void, Never>?
    
    let onPhotoCaptured: (UIImage) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            // Camera Controls Overlay
            VStack {
                Spacer()
                
                // Bottom Controls
                HStack(spacing: Spacing.xxl) {
                    // Flash Toggle
                    Button(action: {
                        Haptics.selection()
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    // Capture Button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            
                            Circle()
                                .fill(isCapturing ? Color.white.opacity(0.5) : Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(isCapturing)
                    
                    // Close Button
                    Button(action: {
                        Haptics.selection()
                        viewModel.stopCamera()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.bottom, 120) // Move up from bottom to avoid nav bar
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .font(.kBody)
                        .foregroundStyle(.white)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.card)
                                .fill(Color.red.opacity(0.9))
                        )
                        .padding(Spacing.md)
                    Spacer()
                }
            }
        }
        .onAppear {
            startCamera()
        }
        .onDisappear {
            setupTask?.cancel()
            setupTask = nil
            viewModel.stopCamera()
        }
        .onChange(of: scenePhase) { _, newValue in
            switch newValue {
            case .active:
                startCamera()
            case .inactive, .background:
                viewModel.stopCamera()
            @unknown default:
                break
            }
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("Please enable camera access in Settings to scan documents and images.")
        }
    }
    
    private func startCamera() {
        setupTask?.cancel()
        setupTask = Task {
            await requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await setupCamera()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupCamera()
            } else {
                showPermissionAlert = true
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showPermissionAlert = true
        }
    }
    
    private func setupCamera() async {
        do {
            try await viewModel.setupCamera()
        } catch {
            do {
                try await Task.sleep(for: .milliseconds(250))
                try await viewModel.setupCamera()
            } catch {
                viewModel.errorMessage = "Failed to start camera. Please try again."
            }
        }
    }
    
    private func capturePhoto() {
        guard !isCapturing else { return }
        
        isCapturing = true
        Haptics.medium()
        
        viewModel.capturePhoto { image in
            isCapturing = false
            
            if let image = image {
                Haptics.success()
                onPhotoCaptured(image)
            } else {
                Haptics.error()
                viewModel.errorMessage = "Failed to capture photo. Please try again."
                
                // Clear error after delay
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.errorMessage = nil
                }
            }
        }
    }
}

