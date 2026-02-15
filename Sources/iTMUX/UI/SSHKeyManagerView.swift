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
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.18),
                        Color(red: 0.05, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if manager.sshKeys.isEmpty {
                    emptyStateView
                } else {
                    keyListView
                }
            }
            .navigationTitle("SSH Keys")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImportKey = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.cyan)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No SSH Keys")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Import an SSH private key to use\nkey-based authentication")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingImportKey = true
            } label: {
                Label("Import Key", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.cyan)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var keyListView: some View {
        List {
            Section {
                ForEach(manager.sshKeys) { key in
                    KeyRow(key: key) {
                        manager.removeSSHKey(key.id)
                    }
                }
            } header: {
                Text("Saved Keys")
                    .foregroundColor(.gray)
            }
            .listRowBackground(Color.white.opacity(0.08))
            
            Section {
                Button {
                    showingImportKey = true
                } label: {
                    Label("Import New Key", systemImage: "plus.circle")
                        .foregroundColor(.cyan)
                }
            }
            .listRowBackground(Color.white.opacity(0.08))
        }
        .scrollContentBackground(.hidden)
    }
    
    private var importKeySheet: some View {
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
                        ActionCard(
                            title: "Import SSH Key",
                            subtitle: "Paste your private key in PEM format",
                            icon: "key.fill",
                            colorScheme: .ocean
                        ) {
                            VStack(spacing: 16) {
                                TextField("Key Name", text: $newKeyName)
                                    .textFieldStyle(.plain)
                                    .padding(14)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                                
                                TextEditor(text: $newKeyPEM)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(height: 200)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if newKeyPEM.isEmpty {
                                            Text("Paste private key here...\n\n-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(12)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                        }
                        
                        tipsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Import Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingImportKey = false
                        newKeyName = ""
                        newKeyPEM = ""
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importKey()
                    }
                    .foregroundColor(.cyan)
                    .disabled(newKeyName.isEmpty || newKeyPEM.isEmpty)
                }
            }
        }
    }
    
    private var tipsCard: some View {
        ActionCard(
            title: "Supported Formats",
            subtitle: nil,
            icon: "info.circle.fill",
            colorScheme: .ocean
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "checkmark.circle", text: "Ed25519 (OpenSSH format)", color: .green)
                TipRow(icon: "circle", text: "RSA (coming soon)", color: .gray)
                TipRow(icon: "circle", text: "ECDSA (coming soon)", color: .gray)
                
                Text("Keys are stored securely in the iOS Keychain")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
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
        HStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundColor(.cyan)
                .frame(width: 36, height: 36)
                .background(Color.cyan.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(key.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(key.publicKeyFingerprint)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Text("Added \(key.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
            
            Spacer()
            
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
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
