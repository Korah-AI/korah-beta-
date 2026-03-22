import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera View Model

@MainActor
@Observable
class CameraViewModel: NSObject {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var isFlashOn = false
    var hasTorch: Bool { currentCamera?.hasTorch ?? false }
    var currentZoomFactor: CGFloat = 1.0
    var isSessionRunning = false
    var isSessionReady = false
    var errorMessage: String?
    
    private var currentCamera: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    private var sessionSetupInProgress = false
    
    override init() {
        super.init()
    }
    
    func setupCamera() async throws {
        // Prevent multiple simultaneous setup attempts
        guard !sessionSetupInProgress else { return }
        sessionSetupInProgress = true
        defer { sessionSetupInProgress = false }
        
        // Clean up any existing session first
        if let existingSession = captureSession {
            if existingSession.isRunning {
                existingSession.stopRunning()
            }
            self.captureSession = nil
            self.photoOutput = nil
            self.isSessionReady = false
            // Small delay to ensure session is fully stopped
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Get camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCameraAvailable
        }
        
        currentCamera = camera
        
        // Add camera input
        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        photoOutput = output
        session.commitConfiguration()
        
        // Set session before starting so preview layer can connect
        await MainActor.run {
            self.captureSession = session
        }
        
        // Start session on background thread
        let startResult = await Task.detached(priority: .userInitiated) {
            session.startRunning()
            // Wait a bit for the session to actually start
            var attempts = 0
            while !session.isRunning && attempts < 50 {
                try? await Task.sleep(for: .milliseconds(50))
                attempts += 1
            }
            return session.isRunning
        }.value
        
        await MainActor.run {
            self.isSessionRunning = startResult
            self.isSessionReady = startResult
            if startResult {
                self.isFlashOn = false
                self.setTorch(on: false)
            } else {
                self.errorMessage = "Camera failed to start. Please try again."
            }
        }
    }
    
    func stopCamera() {
        if let session = captureSession {
            if session.isRunning {
                session.stopRunning()
            }
        }
        setTorch(on: false)
        isSessionRunning = false
        isSessionReady = false
    }
    
    func restartCameraIfNeeded() async {
        guard let session = captureSession, !session.isRunning else { return }
        
        do {
            try await setupCamera()
        } catch {
            errorMessage = "Failed to restart camera. Please try again."
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
        isFlashOn.toggle()
        setTorch(on: isFlashOn)
    }
    
    private func setTorch(on: Bool) {
        guard let device = currentCamera else { return }
        guard device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to set torch: \(error)")
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = currentCamera else { return }
        
        do {
            try device.lockForConfiguration()
            let clampedFactor = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }
    
    enum CameraError: Error {
        case noCameraAvailable
        case unauthorized
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
    let isSessionReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        context.coordinator.containerView = view
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update layer frame when view bounds change
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
        
        // Reconnect layer if session became ready
        if isSessionReady, let previewLayer = context.coordinator.previewLayer {
            if previewLayer.session !== session {
                previewLayer.session = session
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var containerView: UIView?
    }
    
    // Custom UIView that handles layer layout properly
    class PreviewContainerView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            // Ensure sublayers are updated
            layer.sublayers?.forEach { sublayer in
                if sublayer is AVCaptureVideoPreviewLayer {
                    sublayer.frame = bounds
                }
            }
        }
    }
}

// MARK: - Custom Camera View

struct CustomCameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var showPermissionAlert = false
    @State private var isCapturing = false
    @State private var hasAppeared = false
    
    let onPhotoCaptured: (UIImage) -> Void
    let onDismiss: () -> Void
    
    private struct CameraLoadingView: View {
        @State private var isAnimating = false
        
        var body: some View {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .opacity(isAnimating ? 1.0 : 0.5)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("Initializing camera...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession, viewModel.isSessionReady {
                CameraPreviewView(session: session, isSessionReady: viewModel.isSessionReady)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                // Loading state while camera initializes
                CameraLoadingView()
            }
            
            // Camera Controls Overlay
            VStack {
                Spacer()
                
                // Bottom Controls
                HStack(spacing: Spacing.xxl) {
                    if viewModel.hasTorch {
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
                        .disabled(!viewModel.isSessionReady)
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
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await requestCameraPermission()
        }
        .onAppear {
            // Restart camera if it was stopped but view is appearing again
            Task {
                await viewModel.restartCameraIfNeeded()
            }
        }
        .onDisappear {
            hasAppeared = false
            viewModel.stopCamera()
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
            // Retry once after a short delay
            try? await Task.sleep(for: .milliseconds(500))
            do {
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

