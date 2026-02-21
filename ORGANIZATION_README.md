# Korah

> **Free AI-powered tutoring and study tools made for underrepresented students.**

Korah is an iOS app that combines AI tutoring with comprehensive study tools to help students succeed academically. Built with Swift and SwiftUI, Korah provides an accessible, intelligent learning companion that adapts to each student's needs.

---

## 🌟 Features

### 💬 AI Tutor Chat
- **Text & Voice Conversations**: Engage with an AI tutor through text or voice input
- **Guided Learning**: Get step-by-step explanations rather than just answers
- **Multi-Modal Support**: Upload images of homework problems, diagrams, or notes
- **Context-Aware**: Maintains conversation history for coherent, personalized tutoring

### 📚 Study Tools
- **Flashcards**: Create custom flashcard sets or generate them using AI
- **Study Guides**: Build comprehensive study guides for any topic
- **Practice Tests**: Auto-generate practice questions from your materials
- **Study Sessions**: Interactive review modes with progress tracking

### 📸 Document Scanning
- **Camera Integration**: Take pictures of homework, textbooks, or handwritten notes
- **AI Analysis**: Get instant help understanding scanned content
- **Multi-Format Support**: Works with text, diagrams, equations, and more

### ✅ Task Management
- **Todo Lists**: Organize assignments and study tasks
- **Focus Timer**: Pomodoro-based focus sessions with customizable durations (5, 15, 25 minutes)
- **Live Activities**: Track your focus sessions on the Lock Screen and Dynamic Island (iOS 16.1+)
- **Interactive Controls**: Pause, resume, or end sessions without opening the app

### 📊 Mood & Productivity Tracking
- **Daily Check-Ins**: Monitor focus levels and emotional state
- **Personalized Recommendations**: Get task suggestions based on your mood
- **Streak Tracking**: Build study habits with daily streak counters
- **Smart Notifications**: Reminders to maintain your learning streak

---

## 🏗️ Architecture

### **iOS App**
- **Language**: Swift 6.2+
- **Framework**: SwiftUI with `@Observable` pattern
- **Target**: iOS 26.0+
- **Data Management**: SwiftData for local persistence
- **Concurrency**: Modern Swift concurrency (async/await)

### **Backend API**
- **Platform**: Vercel serverless functions
- **Language**: JavaScript (ES Modules)
- **AI Model**: OpenAI GPT-4o (streaming support)
- **Rate Limiting**: Redis-based token tracking via Upstash
- **Endpoints**:
  - `/api/proxy`: Non-streaming chat completions
  - `/api/proxy-stream`: Streaming chat responses
  - `/api/transcribe`: Voice-to-text transcription
  - `/api/speak`: Text-to-speech generation
  - `/api/feedback`: User feedback collection

### **Key Components**
- **DeviceIDManager**: Anonymous user identification for rate limiting
- **NetworkMonitor**: Connection status tracking
- **StreakManager**: Daily engagement tracking
- **StudyDataManager**: Flashcards, guides, and test persistence
- **NotificationManager**: Local notifications and reminders

---

## 🚀 Getting Started

### Prerequisites
- Xcode 16.0+
- iOS device running iOS 26.0+ (or simulator)
- Node.js 18+ (for local API development)
- Vercel account (for deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/korah-beta.git
   cd korah-beta
   ```

2. **Install API dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   Create a `.env` file in the project root:
   ```bash
   OPENAI_API_KEY=your_openai_api_key
   UPSTASH_REDIS_REST_URL=your_upstash_url
   UPSTASH_REDIS_REST_TOKEN=your_upstash_token
   ```

4. **Open in Xcode**
   ```bash
   open "Korah (Beta).xcodeproj"
   ```

5. **Build and run**
   - Select your target device
   - Press `Cmd+R` to build and run

### Testing Live Activities

Live Activities require a **physical device** with iOS 16.1+:

1. Ensure the `FocusTimerWidget` extension is added to your project
2. Enable proper code signing for both app and widget targets
3. Build and install on your device
4. Start a focus session to see Live Activities on the Lock Screen
5. On iPhone 14 Pro+ or 15 Pro+, experience Dynamic Island integration

---

## 🎨 Design System

Korah uses a consistent design system following Apple's Human Interface Guidelines:

- **Typography**: Dynamic Type with semantic styles
- **Colors**: Semantic color system with dark mode support
- **Spacing**: Consistent spacing scale
- **Components**: Reusable SwiftUI components

---

## 📱 App Structure

```
Korah (Beta)/
├── DesignSystem/          # Theme, colors, typography, spacing
├── Managers/              # Core business logic
│   ├── AppStateManager
│   ├── DeviceIDManager
│   ├── NetworkMonitor
│   ├── NotificationManager
│   ├── StreakManager
│   └── StudyDataManager
├── Models/                # Data models
├── Views/
│   ├── Authentication/    # Onboarding, mood check-ins
│   ├── Chat/             # AI tutor interface
│   ├── Scanner/          # Camera and document scanning
│   ├── Study/            # Flashcards, guides, tests
│   ├── Tasks/            # Todo lists and focus timer
│   └── Feedback/         # User feedback
└── Helpers/              # Utilities and extensions

FocusTimerWidget/         # Live Activities widget extension
api/                       # Vercel serverless functions
```

---

## 🔐 Privacy & Security

- **Anonymous Usage**: Device IDs are generated locally, no personal data collected
- **Rate Limiting**: Fair usage enforced through token-based limits
- **Secure API Calls**: All requests include device identification headers
- **Local Storage**: Study data stored exclusively on-device using SwiftData

---

## 🛣️ Roadmap

### Current Focus
- ✅ Enhanced AI responses with better prompting
- ✅ Streaming API support for improved latency
- ✅ Focus Timer with Live Activities
- 🔄 Markdown rendering for AI responses
- 🔄 Auto-cropping for scanned documents

### Upcoming Features
- **Screen Time Integration**: Block distracting apps during focus sessions
- **Focus Analytics**: Track session history and productivity trends
- **Custom Timer Presets**: Save favorite focus durations
- **Break Reminders**: Automated break suggestions
- **Web Version**: Browser-based access for cross-platform use
- **Test Prep Modes**: Specialized AP/SAT preparation tools

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's bug fixes, new features, or documentation improvements, your help makes Korah better for students everywhere.

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Guidelines
- Follow Swift best practices and the project's existing patterns
- Use `@Observable` classes marked with `@MainActor` for shared state
- Prefer modern Swift concurrency over legacy GCD
- Write unit tests for core logic
- Ensure code passes SwiftLint (if configured)
- Include `Co-Authored-By: Warp <agent@warp.dev>` in commit messages

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/korah-beta/issues)
- **Website**: [korah.app](https://korah.app)

---

## 🙏 Acknowledgments

Korah is built to serve underrepresented students and make quality education accessible to everyone. Special thanks to all beta testers and contributors who help shape this platform.

---

<div align="center">
Made with ❤️ for students everywhere
</div>
