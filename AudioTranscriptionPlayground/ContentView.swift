import SwiftUI
import Speech
import AVFoundation
import Combine
import Observation

@Observable class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    
    var transcription: String = "Transcription"
    var isTranscribing: Bool = false
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    func startTranscribing() {
        self.speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                DispatchQueue.main.async {
                    self.isTranscribing = true
                }
                self.startRecording()
            case .denied, .restricted, .notDetermined:
                print("Speech recognition not authorized")
            @unknown default:
                fatalError("Unknown authorization status")
            }
        }
    }
    
    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .interruptSpokenAudioAndMixWithOthers)
            //            try audioSession.setCategory(.record, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine couldn't start")
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcription = result.bestTranscription.formattedString
                    if error != nil || result.isFinal == true {
                        self.stopTranscribing()
                    }
                }
            }
        }
    }
    
    func stopTranscribing() {
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.readTranscription()
        }
    }
    
    func readTranscription() {
        let utterance = AVSpeechUtterance(string: self.transcription)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}


struct ContentView: View {
    @State private var text: String = "Hello"
    private let synthesizer = AVSpeechSynthesizer()
    @State private var speechRecognizer = SpeechRecognizer()
    
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(5)
            
            Button(action: {
                speakText()
            }) {
                Text("Speak")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
            .padding()
            
            Divider()
                .padding()
            
            
            Text(speechRecognizer.transcription)
                .frame(maxWidth: UIScreen.main.bounds.size.width)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(5)
            
            Button(action: {
                if speechRecognizer.isTranscribing {
                    speechRecognizer.stopTranscribing()
                } else {
                    speechRecognizer.startTranscribing()
                }
            }) {
                Text(speechRecognizer.isTranscribing ? "Stop Transcribing" : "Start Transcribing")
                    .padding()
                    .background(speechRecognizer.isTranscribing ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            
        }
        .padding()
    }
    
    func speakText() {
        let utterance = AVSpeechUtterance(string: $text.wrappedValue)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
