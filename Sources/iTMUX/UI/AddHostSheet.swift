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

    private var selectedAccent: Color {
        selectedColorScheme.liquidAccent
    }

    private var isValid: Bool {
        !displayName.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeoLiquidBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        hostDetailsCard
                        colorSchemeCard
                        authOptionsCard
                    }
                    .padding()
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Add Host")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .liquidNavigationBackgroundHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(NeoLiquidPalette.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHost()
                    }
                    .foregroundColor(selectedAccent)
                    .disabled(!isValid)
                }
            }
        }
    }

    private var heroCard: some View {
        NeoGlassCard(accent: selectedAccent, cornerRadius: 26, padding: 18) {
            HStack(spacing: 12) {
                NeoRoboGlyph(symbol: selectedColorScheme.glyphSymbol, accent: selectedAccent, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Neo-Rig Manifest")
                        .font(.headline)
                        .foregroundColor(NeoLiquidPalette.textPrimary)
                    Text("Define host identity, intent, and connection ritual.")
                        .font(.caption)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var hostDetailsCard: some View {
        ActionCard(
            title: "Host Details",
            subtitle: "Create a production-grade endpoint profile",
            icon: "server.rack",
            colorScheme: selectedColorScheme
        ) {
            VStack(spacing: 12) {
                InputField(
                    icon: "tag.fill",
                    placeholder: "Display Name (e.g., Primary Cluster)",
                    text: $displayName,
                    accent: selectedAccent
                )

                InputField(
                    icon: "network",
                    placeholder: "Hostname (e.g., 192.168.1.100)",
                    text: $hostname,
                    autocapitalization: false,
                    keyboardType: .URL,
                    accent: selectedAccent
                )

                InputField(
                    icon: "person.fill",
                    placeholder: "Username",
                    text: $username,
                    autocapitalization: false,
                    accent: selectedAccent
                )

                HStack(spacing: 10) {
                    InputField(
                        icon: "number",
                        placeholder: "Port",
                        text: $port,
                        keyboardType: .numberPad,
                        accent: selectedAccent
                    )

                    InputField(
                        icon: "terminal.fill",
                        placeholder: "Session",
                        text: $sessionName,
                        autocapitalization: false,
                        accent: selectedAccent
                    )
                }
            }
        }
    }

    private var colorSchemeCard: some View {
        ActionCard(
            title: "Color Vessel",
            subtitle: "Tune the host aura and glyph identity",
            icon: "swatchpalette",
            colorScheme: selectedColorScheme
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
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
            subtitle: "Choose your trust handshake",
            icon: "key.horizontal.fill",
            colorScheme: selectedColorScheme
        ) {
            VStack(spacing: 14) {
                Toggle(isOn: $useKeyAuth) {
                    HStack(spacing: 10) {
                        Image(systemName: useKeyAuth ? "key.fill" : "lock.fill")
                            .foregroundColor(selectedAccent)
                        Text(useKeyAuth ? "SSH Key Mode" : "Password Mode")
                            .foregroundColor(NeoLiquidPalette.textPrimary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: selectedAccent))

                if useKeyAuth {
                    if manager.sshKeys.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(NeoLiquidPalette.auraAmber)
                            Text("No SSH keys configured yet.")
                                .font(.caption)
                                .foregroundColor(NeoLiquidPalette.textSecondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Picker("Select Key", selection: $selectedKeyId) {
                            Text("Select a key").tag(nil as UUID?)
                            ForEach(manager.sshKeys) { key in
                                Text(key.name).tag(key.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .neoInputSurface(accent: selectedAccent)
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
    var accent: Color = NeoLiquidPalette.auraCyan

    enum KeyboardType {
        case `default`, URL, numberPad
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                #if os(iOS)
                .textInputAutocapitalization(autocapitalization ? .sentences : .never)
                .keyboardType(keyboardType == .URL ? .URL : (keyboardType == .numberPad ? .numberPad : .default))
                #endif
                .autocorrectionDisabled()
        }
        .neoInputSurface(accent: accent)
    }
}

struct ColorSchemeButton: View {
    let scheme: HostColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(scheme.liquidAccent.opacity(0.22))
                        .frame(width: 48, height: 48)
                    NeoRoboGlyph(symbol: scheme.glyphSymbol, accent: scheme.liquidAccent, size: 40)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                        .frame(width: 48, height: 48)
                )

                Text(scheme.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isSelected ? NeoLiquidPalette.textPrimary : NeoLiquidPalette.textMuted)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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
                .foregroundColor(NeoLiquidPalette.textSecondary)
            Spacer()
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
        NeoGlassCard(accent: colorScheme.liquidAccent, cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                NeoSectionTitle(
                    title: title,
                    subtitle: subtitle ?? "",
                    symbol: icon,
                    accent: colorScheme.liquidAccent
                )

                content
            }
        }
    }
}

#Preview {
    AddHostSheet(manager: ConnectionManager())
}
