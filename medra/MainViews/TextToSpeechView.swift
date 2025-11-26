//
//  TextToSpeechView.swift
//  medra
//
//  Created by admin on 2025/11/24.
//

import SwiftUI
import AVFoundation
import Combine
import NaturalLanguage
import UniformTypeIdentifiers

class SpeechViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var voices: [AVSpeechSynthesisVoice] = []
    
    // Settings
    @AppStorage("tts_rate") var rate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("tts_pitch") var pitch: Double = 1.0
    @AppStorage("tts_voice") var selectedVoiceIdentifier: String?
    
    private var synthesizer = AVSpeechSynthesizer()
    private let exportSynthesizer = AVSpeechSynthesizer() // Dedicated synthesizer for exports
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadVoices()
    }
    
    func loadVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices()
        
        // If no voice is selected, or the selected voice is no longer available, default to current locale
        if selectedVoiceIdentifier == nil || !voices.contains(where: { $0.identifier == selectedVoiceIdentifier }) {
            if let current = AVSpeechSynthesisVoice(language: Locale.current.identifier) {
                selectedVoiceIdentifier = current.identifier
            } else {
                selectedVoiceIdentifier = voices.first?.identifier
            }
        }
    }
    
    private func checkLanguageMismatch(text: String) -> Bool {
        guard let voiceId = selectedVoiceIdentifier,
              let voice = voices.first(where: { $0.identifier == voiceId }) else {
            return false
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let detectedLanguage = recognizer.dominantLanguage else {
            return false
        }
        
        let voiceLanguageCode = voice.language.prefix(2)
        let detectedLanguageCode = detectedLanguage.rawValue.prefix(2)
        
        // Simple check: if the first two letters (e.g., "en", "zh") don't match, it's a likely mismatch.
        // Note: This is a heuristic. Some voices might support multiple languages or be close enough.
        if voiceLanguageCode != detectedLanguageCode {
            errorMessage = "Language Mismatch: Text detected as \(detectedLanguage.rawValue), but voice is \(voice.language). Playback may fail."
            return true
        }
        
        return false
    }
    
    func toggleSpeech(text: String) {
        errorMessage = nil // Clear previous errors
        
        if synthesizer.isSpeaking {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                isSpeaking = true
            } else {
                synthesizer.stopSpeaking(at: .immediate)
                isSpeaking = false
            }
        } else {
            guard !text.isEmpty else { return }
            
            if checkLanguageMismatch(text: text) {
                // We warn the user but don't block them, or we could block.
                // User asked to "tell the reason why it cannot play".
                // If we proceed, it might just be silent.
                // Let's return here to ensure the user sees the error.
                return
            }
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = Float(rate)
            utterance.pitchMultiplier = Float(pitch)
            if let identifier = selectedVoiceIdentifier {
                utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            }
            
            synthesizer.speak(utterance)
            isSpeaking = true
        }
    }
    
    func saveToFile(text: String, completion: @escaping (URL?) -> Void) {
        errorMessage = nil
        guard !text.isEmpty else {
            errorMessage = "Text is empty."
            completion(nil)
            return
        }
        
        if checkLanguageMismatch(text: text) {
            completion(nil)
            return
        }
        
        isSaving = true // Start loading
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Float(rate)
        utterance.pitchMultiplier = Float(pitch)
        if let identifier = selectedVoiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        }
        
        // Use Documents directory for better accessibility
        let fileName = "speech_\(Date().timeIntervalSince1970).wav"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Failed to access Documents directory."
            isSaving = false
            completion(nil)
            return
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        DispatchQueue.global(qos: .userInitiated).async {
            var audioFile: AVAudioFile?
            var errorOccurred: Error?
            var didWriteAudio = false
            var lastBufferTime = Date()
            let timeoutInterval: TimeInterval = 2.0 // Consider done if no buffers for 2 seconds
            
            self.exportSynthesizer.write(utterance) { buffer in
                lastBufferTime = Date()
                
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                
                // Skip empty buffers
                if pcmBuffer.frameLength == 0 { return }
                
                if audioFile == nil {
                    do {
                        let settings = pcmBuffer.format.settings
                        audioFile = try AVAudioFile(
                            forWriting: fileURL,
                            settings: settings,
                            commonFormat: pcmBuffer.format.commonFormat,
                            interleaved: pcmBuffer.format.isInterleaved
                        )
                    } catch {
                        errorOccurred = error
                        return
                    }
                }
                
                do {
                    try audioFile?.write(from: pcmBuffer)
                    didWriteAudio = true
                } catch {
                    errorOccurred = error
                }
            }
            
            // Wait for write to complete by monitoring when buffers stop coming
            while Date().timeIntervalSince(lastBufferTime) < timeoutInterval {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Close the audio file to release the file handle
            audioFile = nil
            
            DispatchQueue.main.async {
                self.isSaving = false // Stop loading
                
                if let error = errorOccurred {
                    self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                    completion(nil)
                } else if !didWriteAudio {
                    self.errorMessage = "Failed to generate audio. Please check if the selected voice supports the text language."
                    try? FileManager.default.removeItem(at: fileURL)
                    completion(nil)
                } else {
                    completion(fileURL)
                }
            }
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
}

struct AudioFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.wav, .audio] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsSheet: View {
    @ObservedObject var viewModel: SpeechViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice")) {
                    Picker("Voice", selection: $viewModel.selectedVoiceIdentifier) {
                        ForEach(viewModel.voices, id: \.identifier) { voice in
                            Text("\(voice.language) - \(voice.name)").tag(Optional(voice.identifier))
                        }
                    }
                }
                
                Section(header: Text("Speech Rate")) {
                    VStack {
                        Slider(value: $viewModel.rate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate))
                        Text(String(format: "%.2f", viewModel.rate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Pitch")) {
                    VStack {
                        Slider(value: $viewModel.pitch, in: 0.5...2.0)
                        Text(String(format: "%.2f", viewModel.pitch))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct TextToSpeechView: View {
    @StateObject private var viewModel = SpeechViewModel()
    @State private var text: String = ""
    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var showFileExporter = false
    @State private var audioDocument: AudioFileDocument?
    @State private var exportFileName: String = "speech.wav"
    
    var body: some View {
        VStack(spacing: 20) {   
                        
            // Action Buttons
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.toggleSpeech(text: text)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(viewModel.isSpeaking ? "Stop" : "Play")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isSpeaking ? .red : .blue)
                    
                    Button(action: {
                        viewModel.saveToFile(text: text) { url in
                            if let url = url {
                                do {
                                    let data = try Data(contentsOf: url)
                                    audioDocument = AudioFileDocument(data: data)
                                    exportFileName = url.lastPathComponent
                                    showFileExporter = true
                                } catch {
                                    viewModel.errorMessage = "Failed to prepare file for export: \(error.localizedDescription)"
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(viewModel.isSaving ? "Saving..." : "iCloud")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemGroupedBackground))
                
                // Bottom Separator
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }         
            // Text Input Area
            VStack(alignment: .leading) {
                HStack {
                    Text("Enter Text:")
                        .font(.headline)
                    Spacer()
                    Button("Import Text File") {
                        showFileImporter = true
                    }
                    .font(.subheadline)
                }
                
                TextEditor(text: $text)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(minHeight: 200)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .contentShape(Rectangle()) // Ensure the entire area is tappable
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Text to Speech")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button(action: {
            showSettings = true
        }) {
            Image(systemName: "gear")
        })
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: audioDocument,
            contentType: .wav,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                viewModel.errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importTextFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func importTextFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            viewModel.errorMessage = "Permission denied."
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            text = try String(contentsOf: url)
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }
}
#Preview {
    NavigationView {
        TextToSpeechView()
    }
}
