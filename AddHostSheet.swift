import SwiftUI

struct AddHostSheet: View {
    @ObservedObject var manager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var selectedColorScheme: HostColorScheme = .ocean
    
    private var isValid: Bool {
        !displayName.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.3, blue: 0.5),
                        Color(red: 0.3, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Host Details Card
                        ActionCard(
                            title: "Host Details",
                            subtitle: "Configure your remote server",
                            icon: "server.rack",
                            colorScheme: selectedColorScheme
                        ) {
                            VStack(spacing: 12) {
                                InputField(
                                    icon: "tag.fill",
                                    placeholder: "Display Name (e.g., MacBook Pro)",
                                    text: $displayName
                                )
                                
                                InputField(
                                    icon: "globe",
                                    placeholder: "Hostname (e.g., 192.168.1.100)",
                                    text: $hostname
                                )
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                
                                InputField(
                                    icon: "person.fill",
                                    placeholder: "Username",
                                    text: $username
                                )
                                .textInputAutocapitalization(.never)
                                
                                InputField(
                                    icon: "network",
                                    placeholder: "Port (default: 22)",
                                    text: $port
                                )
                                .keyboardType(.numberPad)
                            }
                        }
                        
                        // Color Scheme Picker
                        ActionCard(
                            title: "Color Theme",
                            subtitle: "Choose a color to identify this host",
                            icon: "paintpalette.fill",
                            colorScheme: selectedColorScheme
                        ) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(HostColorScheme.allCases, id: \.self) { scheme in
                                    ColorSchemeButton(
                                        scheme: scheme,
                                        isSelected: selectedColorScheme == scheme
                                    ) {
                                        selectedColorScheme = scheme
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHost()
                    }
                    .foregroundColor(.white)
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
            }
        }
    }
    
    private func addHost() {
        let host = RemoteHost(
            displayName: displayName,
            hostname: hostname,
            username: username,
            port: Int(port) ?? 22,
            colorScheme: selectedColorScheme
        )
        manager.addHost(host)
        dismiss()
    }
}

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ColorSchemeButton: View {
    let scheme: HostColorScheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(scheme.statusBarColor)
                    .frame(height: 50)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                
                Text(scheme.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}
