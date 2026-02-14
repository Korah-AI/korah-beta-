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
    var currentZoomFactor: CGFloat = 1.0
    var isSessionRunning = false
    var errorMessage: String?
    
    private var currentCamera: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
    }
    
    func setupCamera() async throws {
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
        captureSession = session
        
        // Start session on background thread
        Task.detached {
            session.startRunning()
            await MainActor.run {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopCamera() {
        captureSession?.stopRunning()
        isSessionRunning = false
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
    @State private var viewModel = CameraViewModel()
    @State private var showPermissionAlert = false
    @State private var isCapturing = false
    
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
            await requestCameraPermission()
        }
        .onDisappear {
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
            viewModel.errorMessage = "Failed to start camera. Please try again."
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

