this is me testing out the gitub repository

KORAH APP
=========

An AI-powered tutoring and study companion app for students.

AI DISCLOSURE
-------------
This app was developed with assistance from AI coding tools:
- Warp AI (in terminal): Used for complex Swift coding tasks including voice mode implementation, 
  audio recording/playback with AVFoundation, OpenAI API integration, real-time speech 
  transcription, and UI state management.
- ChatGPT in Xcode: Assisted with SwiftUI layout debugging, data persistence with @AppStorage,
  navigation flows, and JSON parsing for structured AI responses.

This is our first time coding in Swift and C++ (for the Arduino bracelet hardware). 
AI tools were essential for learning syntax, debugging, and implementing features beyond 
our initial skill level.

REQUIREMENTS
------------
- iOS 18.0 or later
- Custom Arduino-based wellness bracelet (optional, for mood tracking features)
- OpenAI API key (required for chat and voice features)

FEATURES
--------
- AI Tutor Chat: Text and voice conversations with guided learning
- Study Tools: Flashcards, study guides, and practice tests
- Document Scanning: Extract text from images using Vision framework
- Task Management: To-do lists with Pomodoro timer
- Mood Tracking: Integration with custom Arduino bracelet via Bluetooth

HARDWARE
--------
The bracelet communicates via Bluetooth LE to provide wellness insights.
The app functions fully without the bracelet, but mood tracking features are enhanced with it.

DEVELOPMENT
-----------
Built using Swift, SwiftUI, and AVFoundation.
Arduino firmware written in C++.
API integration with OpenAI for GPT-3.5-turbo and Whisper models.
