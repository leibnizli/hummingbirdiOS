//
//  SpeechToTextView.swift
//  medra
//
//  Created by admin on 2025/11/24.
//

import SwiftUI
import Speech
import AVFoundation

struct AudioToTextView: View {
    @State private var transcription: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var selectedFileName: String?
    
    @State private var isPermissionDenied = false
    @State private var isCopied = false
    
    // Speech Recognition


    // MARK: - Language Support
    struct Language: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let code: String
    }
    
    let languages = [
        Language(name: "English (US)", code: "en-US"),
        Language(name: "Chinese (Simplified)", code: "zh-CN"),
        Language(name: "Chinese (Traditional)", code: "zh-TW"),
        Language(name: "Japanese", code: "ja-JP"),
        Language(name: "Korean", code: "ko-KR"),
        Language(name: "Spanish", code: "es-ES"),
        Language(name: "French", code: "fr-FR"),
        Language(name: "German", code: "de-DE"),
        Language(name: "Italian", code: "it-IT"),
        Language(name: "Portuguese", code: "pt-PT"),
        Language(name: "Russian", code: "ru-RU")
    ]
    
    @AppStorage("stt_language") private var selectedLanguageCode = "en-US"

    var body: some View {
        VStack(spacing: 20) {
            if isPermissionDenied {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Permission Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please enable Speech Recognition permission in Settings to use this feature.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                fileModeView
                
                // Transcription Output
                VStack(alignment: .leading) {
                    HStack {
                        Text("Transcription:")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !transcription.isEmpty {
                            Button(action: {
                                UIPasteboard.general.string = transcription
                                isCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isCopied = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    Text(isCopied ? "Copied" : "Copy")
                                }
                                .font(.caption)
                                .foregroundColor(isCopied ? .green : .blue)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                    
                    ScrollView {
                        Text(transcription)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
            }
        }
        .navigationTitle("Audio to Text")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            requestPermissions()
        }
    }
    
    // MARK: - File Mode View
    var fileModeView: some View {
        VStack(spacing: 16) {
            // Language Picker
            HStack {
                Text("Language:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Language", selection: $selectedLanguageCode) {
                    ForEach(languages) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            Button(action: {
                showFileImporter = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(selectedFileName ?? "Select Audio File")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        processAudioFile(url: url)
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            
            if isProcessing {
                ProgressView("Transcribing...")
            }
        }
    }
    
    // MARK: - Logic
    
    private func resetState() {
        transcription = ""
        errorMessage = nil
        isProcessing = false
        selectedFileName = nil
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.isPermissionDenied = false
                case .denied, .restricted:
                    self.isPermissionDenied = true
                case .notDetermined:
                    self.isPermissionDenied = false
                @unknown default:
                    self.isPermissionDenied = true
                }
            }
        }
    }
    
    private func processAudioFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Permission denied to access file."
            return
        }
        
        // Do NOT defer stopAccessingSecurityScopedResource here because SFSpeechURLRecognitionRequest reads asynchronously.
        // We must stop accessing in the completion handler.
        
        selectedFileName = url.lastPathComponent
        transcription = ""
        isProcessing = true
        errorMessage = nil
        
        // Initialize recognizer with selected locale
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        
        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available for the selected language."
            isProcessing = false
            url.stopAccessingSecurityScopedResource()
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        // Force offline recognition if desired, but usually not strictly required unless network is an issue.
        // request.requiresOnDeviceRecognition = false 
        
        speechRecognizer.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.transcription = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    self.errorMessage = "Transcription error: \(error.localizedDescription)"
                    self.isProcessing = false
                    url.stopAccessingSecurityScopedResource() // Stop access on error
                } else if result?.isFinal == true {
                    self.isProcessing = false
                    url.stopAccessingSecurityScopedResource() // Stop access on completion
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AudioToTextView()
    }
}
