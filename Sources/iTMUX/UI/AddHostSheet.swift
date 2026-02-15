import SwiftUI

struct AddHostSheet: View {
    @ObservedObject var manager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var sessionName = "itmux"
    @State private var selectedColorScheme: HostColorScheme = .ocean
    @State private var useKeyAuth = false
    @State private var selectedKeyId: UUID?
    
    private var isValid: Bool {
        !displayName.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.18),
                        Color(red: 0.05, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        hostDetailsCard
                        colorSchemeCard
                        authOptionsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Host")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHost()
                    }
                    .foregroundColor(.cyan)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var hostDetailsCard: some View {
        ActionCard(
            title: "Host Details",
            subtitle: "Configure your remote server",
            icon: "server.rack",
            colorScheme: selectedColorScheme
        ) {
            VStack(spacing: 14) {
                InputField(
                    icon: "tag.fill",
                    placeholder: "Display Name (e.g., MacBook Pro)",
                    text: $displayName
                )
                
                InputField(
                    icon: "globe",
                    placeholder: "Hostname (e.g., 192.168.1.100)",
                    text: $hostname,
                    autocapitalization: false,
                    keyboardType: .URL
                )
                
                InputField(
                    icon: "person.fill",
                    placeholder: "Username",
                    text: $username,
                    autocapitalization: false
                )
                
                HStack(spacing: 12) {
                    InputField(
                        icon: "network",
                        placeholder: "Port",
                        text: $port,
                        keyboardType: .numberPad
                    )
                    
                    InputField(
                        icon: "terminal",
                        placeholder: "Session",
                        text: $sessionName,
                        autocapitalization: false
                    )
                }
            }
        }
    }
    
    private var colorSchemeCard: some View {
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
    
    private var authOptionsCard: some View {
        ActionCard(
            title: "Authentication",
            subtitle: "Choose how to authenticate",
            icon: "key.fill",
            colorScheme: selectedColorScheme
        ) {
            VStack(spacing: 14) {
                Toggle(isOn: $useKeyAuth) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.cyan)
                        Text("Use SSH Key")
                            .foregroundColor(.white)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                
                if useKeyAuth {
                    if manager.sshKeys.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No SSH keys configured")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Picker("Select Key", selection: $selectedKeyId) {
                            Text("Select a key").tag(nil as UUID?)
                            ForEach(manager.sshKeys) { key in
                                Text(key.name).tag(key.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
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
            colorScheme: selectedColorScheme,
            defaultSessionName: sessionName.isEmpty ? "itmux" : sessionName,
            useKeyAuth: useKeyAuth,
            keyId: selectedKeyId
        )
        
        manager.addHost(host)
        dismiss()
    }
}

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: Bool = true
    var keyboardType: KeyboardType = .default
    
    enum KeyboardType {
        case `default`, URL, numberPad
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                #if os(iOS)
                .textInputAutocapitalization(autocapitalization ? .sentences : .never)
                .keyboardType(keyboardType == .URL ? .URL : (keyboardType == .numberPad ? .numberPad : .default))
                #endif
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
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
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                
                Text(scheme.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .gray)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    var color: Color = .green
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct ActionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let colorScheme: HostColorScheme
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(colorScheme.statusBarColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme.borderColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AddHostSheet(manager: ConnectionManager())
}
