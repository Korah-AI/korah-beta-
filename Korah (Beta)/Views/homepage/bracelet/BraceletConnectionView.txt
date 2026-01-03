import SwiftUI
import CoreBluetooth

struct BraceletConnectionView: View {
    @ObservedObject private var bleManager = BLEManager.shared
    @State private var selectedColor: Color = .purple
    @State private var sliderProgress: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "applewatch.watchface")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Connect to Bracelet")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Connect your Korah bracelet to track your focus and study sessions")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                if bleManager.isConnected {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("FocusBracelet")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            Text("Disconnect")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Button(action: {
                            if bleManager.isScanning {
                                bleManager.stopScanning()
                            } else {
                                bleManager.startScanning()
                            }
                        }) {
                            HStack {
                                if bleManager.isScanning {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Searching...")
                                } else {
                                    Image(systemName: "magnifyingglass")
                                    Text("Scan for Devices")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                        
                        if !bleManager.discoveredPeripherals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Available Devices")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                                    Button(action: {
                                        bleManager.connect(to: peripheral)
                                    }) {
                                        HStack {
                                            Image(systemName: "applewatch")
                                                .foregroundColor(.purple)
                                            
                                            Text(peripheral.name ?? "Unknown Device")
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if bleManager.isConnected {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Bracelet Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme Color")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                ColorPicker("Choose Color", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .scaleEffect(1.5)
                                    .frame(width: 60, height: 60)
                                
                                Button(action: {
                                    let rgb = selectedColor.rgbComponents
                                    let r = Int(rgb.red * 255)
                                    let g = Int(rgb.green * 255)
                                    let b = Int(rgb.blue * 255)
                                    bleManager.sendCommand("COLOR:\(r),\(g),\(b)")
                                    bleManager.themeColor = selectedColor
                                }) {
                                    HStack {
                                        Image(systemName: "paintbrush.fill")
                                        Text("Set Theme Color")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedColor.opacity(0.8))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        Button(action: {
                            bleManager.sendCommand("CHECK")
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Check Connection")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.7))
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                if bleManager.isConnected {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Play Around")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ControlButton(icon: "sparkles", title: "Rainbow", color: .pink) {
                                bleManager.sendCommand("CELEBRATE")
                            }
                            
                            ControlButton(icon: "waveform.path", title: "Pulse", color: .blue) {
                                bleManager.sendCommand("PULSE")
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ControlButton(icon: "bolt.fill", title: "Flash", color: .yellow) {
                                bleManager.sendCommand("FLASH")
                            }
                            
                            ControlButton(icon: "moon.stars.fill", title: "Breathe", color: .indigo) {
                                bleManager.sendCommand("BREATHE")
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ControlButton(icon: "water.waves", title: "Wave", color: .cyan) {
                                bleManager.sendCommand("WAVE")
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ControlButton(icon: "xmark.circle.fill", title: "Reset", color: .red) {
                                bleManager.sendCommand("RESET")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LED Progress Bar")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text("0%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                Slider(value: $sliderProgress, in: 0...100)
                                    .accentColor(selectedColor)
                                    .onChange(of: sliderProgress) { newValue in
                                        let rgb = selectedColor.rgbComponents
                                        let r = Int(rgb.red * 255)
                                        let g = Int(rgb.green * 255)
                                        let b = Int(rgb.blue * 255)
                                        bleManager.sendCommand("PROGRESS:\(Int(newValue)),\(r),\(g),\(b)")
                                    }
                                
                                Text("100%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 40)
                            }
                            
                            Text("\(Int(sliderProgress))%")
                                .font(.title3)
                                .bold()
                                .foregroundColor(selectedColor)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Your Bracelet")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Your Korah bracelet will respond automatically to your tasks and timers. It stays connected in the background, providing haptic feedback and visual cues when you start tasks, complete them, or take breaks.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .korahGradientBackground()
        .navigationTitle("Bracelet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ControlButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.purple)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

import Combine

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()
    
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var themeColor: Color = .purple
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "180A")
    private let commandCharUUID = CBUUID(string: "2A57")
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic,
              isConnected else {
            print("Cannot send command: not connected")
            return
        }
        
        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            print("Sent command: \(command)")
        }
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown")")
        isConnected = false
        connectedPeripheral = nil
        commandCharacteristic = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([commandCharUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == commandCharUUID {
                commandCharacteristic = characteristic
                print("Found command characteristic")
            }
        }
    }
}

extension Color {
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #else
        return (0, 0, 0)
        #endif
    }
}

#Preview {
    NavigationStack {
        BraceletConnectionView()
    }
}

