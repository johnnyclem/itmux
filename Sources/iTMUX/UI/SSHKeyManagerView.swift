import SwiftUI
import Crypto

struct SSHKeyManagerView: View {
    @ObservedObject var manager: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingImportKey = false
    @State private var newKeyName = ""
    @State private var newKeyPEM = ""
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                NeoLiquidBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if manager.sshKeys.isEmpty {
                            emptyStateView
                        } else {
                            keyListView
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("SSH Keys")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .liquidNavigationBackgroundHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(NeoLiquidPalette.textSecondary)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImportKey = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(NeoLiquidPalette.auraCyan)
                    }
                }
            }
            .sheet(isPresented: $showingImportKey) {
                importKeySheet
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }

    private var heroCard: some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraMint, cornerRadius: 24, padding: 16) {
            HStack(spacing: 12) {
                NeoRoboGlyph(symbol: "key.horizontal.fill", accent: NeoLiquidPalette.auraMint, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trust Vault")
                        .font(.headline)
                        .foregroundColor(NeoLiquidPalette.textPrimary)
                    Text("\(manager.sshKeys.count) key\(manager.sshKeys.count == 1 ? "" : "s") available for secure auth.")
                        .font(.caption)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var emptyStateView: some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraAmber, cornerRadius: 24, padding: 20) {
            VStack(spacing: 16) {
                NeoRoboGlyph(symbol: "key.slash", accent: NeoLiquidPalette.auraAmber, size: 64)

                VStack(spacing: 6) {
                    Text("No SSH Keys Imported")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(NeoLiquidPalette.textPrimary)
                    Text("Paste an OpenSSH private key to enable key-based login.")
                        .font(.subheadline)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showingImportKey = true
                } label: {
                    Label("Import Key", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(NeoLiquidButtonStyle(tint: NeoLiquidPalette.auraMint))
            }
        }
    }

    private var keyListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(manager.sshKeys) { key in
                KeyRow(key: key) {
                    manager.removeSSHKey(key.id)
                }
            }

            Button {
                showingImportKey = true
            } label: {
                Label("Import New Key", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(NeoLiquidButtonStyle(tint: NeoLiquidPalette.auraCyan, prominent: false))
        }
    }

    private var importKeySheet: some View {
        NavigationStack {
            ZStack {
                NeoLiquidBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        ActionCard(
                            title: "Import SSH Key",
                            subtitle: "Paste private key (PEM/OpenSSH format)",
                            icon: "key.fill",
                            colorScheme: .emerald
                        ) {
                            VStack(spacing: 12) {
                                TextField("Key Name", text: $newKeyName)
                                    .neoInputSurface(accent: NeoLiquidPalette.auraMint)

                                TextEditor(text: $newKeyPEM)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(height: 220)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(NeoLiquidPalette.auraMint.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if newKeyPEM.isEmpty {
                                            Text("Paste private key...\n\n-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----")
                                                .font(.caption)
                                                .foregroundColor(NeoLiquidPalette.textMuted)
                                                .padding(14)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                        }

                        tipsCard
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Import Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .liquidNavigationBackgroundHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingImportKey = false
                        newKeyName = ""
                        newKeyPEM = ""
                    }
                    .foregroundColor(NeoLiquidPalette.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importKey()
                    }
                    .foregroundColor(NeoLiquidPalette.auraMint)
                    .disabled(newKeyName.isEmpty || newKeyPEM.isEmpty)
                }
            }
        }
    }

    private var tipsCard: some View {
        ActionCard(
            title: "Supported Formats",
            subtitle: "Secure key compatibility",
            icon: "checkmark.shield",
            colorScheme: .emerald
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "checkmark.circle.fill", text: "Ed25519 (OpenSSH format)", color: .green)
                TipRow(icon: "circle", text: "RSA (coming soon)", color: NeoLiquidPalette.textMuted)
                TipRow(icon: "circle", text: "ECDSA (coming soon)", color: NeoLiquidPalette.textMuted)

                Text("Keys are stored in Keychain-backed secure storage.")
                    .font(.caption)
                    .foregroundColor(NeoLiquidPalette.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    private func importKey() {
        let fingerprint = generateFingerprint(from: newKeyPEM)

        manager.addSSHKey(
            name: newKeyName,
            privateKeyPEM: Data(newKeyPEM.utf8),
            publicKeyFingerprint: fingerprint
        )

        showingImportKey = false
        newKeyName = ""
        newKeyPEM = ""
    }

    private func generateFingerprint(from pem: String) -> String {
        let cleaned = pem
            .replacingOccurrences(of: "-----BEGIN.*?-----", with: "", options: .regularExpression)
            .replacingOccurrences(of: "-----END.*?-----", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)

        guard let data = Data(base64Encoded: cleaned) else {
            return "invalid"
        }

        let hash = SHA256.hash(data: data)
        let fingerprint = hash.compactMap { String(format: "%02x", $0) }.joined(separator: ":")

        return "SHA256:" + String(fingerprint.prefix(47))
    }
}

struct KeyRow: View {
    let key: SSHKey
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraCyan, cornerRadius: 20, padding: 14) {
            HStack(spacing: 12) {
                NeoRoboGlyph(symbol: "key.fill", accent: NeoLiquidPalette.auraCyan, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(key.name)
                        .font(.headline)
                        .foregroundColor(NeoLiquidPalette.textPrimary)

                    Text(key.publicKeyFingerprint)
                        .font(.caption2.monospaced())
                        .foregroundColor(NeoLiquidPalette.textMuted)
                        .lineLimit(1)

                    Text("Added \(key.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                }

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(NeoLiquidPalette.auraRose)
                }
            }
        }
        .confirmationDialog("Delete Key?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove '\(key.name)' from your saved keys.")
        }
    }
}

#Preview {
    SSHKeyManagerView(manager: ConnectionManager())
}
