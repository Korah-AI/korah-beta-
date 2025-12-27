import SwiftUI

struct HomePageView: View {
    @State private var selectedTab: Int = 0
    @State private var showMoodPicker: Bool = false
    @State private var showTimerCelebration = false

    @AppStorage("UserMood") private var userMood: String = ""

    @ObservedObject private var dataManager = HomeDataManager.shared
    @ObservedObject private var timerManager = PomodoroTimerManager.shared

    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Hello, Student! 👋")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Upcoming Tasks")
                                .font(.title3)
                                .foregroundColor(.white)
                                .bold()

                            Spacer()

                            Button(action: {
                                showMoodPicker = true
                            }) {
                                Text(userMood.isEmpty ? "🟢" : userMood)
                                    .font(.largeTitle)
                            }
                        }

                        if dataManager.tasks.isEmpty {
                            Text("No upcoming tasks.")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        } else {
                            ForEach(dataManager.tasks.prefix(3)) { task in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(task.title)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    if !task.description.isEmpty {
                                        Text(task.description)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }

                                    Text("Due: \(task.dueDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Study it again.")
                            .font(.title3)
                            .foregroundColor(.white)
                            .bold()
                            .padding(.horizontal)

                        if dataManager.recentStudyItems.isEmpty {
                            Text("No recent study items.")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .padding(.horizontal)
                        } else {
                            ForEach(dataManager.recentStudyItems.prefix(3)) { item in
                                NavigationLink(destination: homeDestination(for: item.id, kind: item.kind)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text(item.kind)
                                                .font(.caption2)
                                                .bold()
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.purple.opacity(0.2))
                                                .foregroundColor(.purple)
                                                .cornerRadius(8)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        Button(action: {
                            selectedTab = 5
                        }) {
                            Text("Go to Study")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        Text("Start a new chat with Korah")
                            .font(.title3)
                            .foregroundColor(.white)
                            .bold()

                        Button(action: {
                            selectedTab = 3 
                        }) {
                            Text("Chat Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Text("Connect your Korah Bracelet")
                            .font(.title3)
                            .foregroundColor(.white)
                            .bold()

                        NavigationLink(destination: BraceletConnectionView()) {
                            HStack {
                                Image(systemName: "applewatch")
                                    .font(.title3)
                                Text("Connect to Bracelet")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    Spacer()
                    }
                }
                .background(Color.korahBackgroundStart.ignoresSafeArea())
                .sheet(isPresented: $showMoodPicker) {
                    VStack(spacing: 16) {
                        Text("Update your focus")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("How are you feeling now?")
                            .foregroundColor(.secondary)
                        VStack(spacing: 12) {
                            Button {
                                userMood = "🟢"
                                UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                showMoodPicker = false
                            } label: {
                                HStack { Text("🟢").font(.largeTitle); Text("Very focused, ready to go").foregroundColor(.white) }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.3))
                                    .cornerRadius(12)
                            }
                            Button {
                                userMood = "🟡"
                                UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                showMoodPicker = false
                            } label: {
                                HStack { Text("🟡").font(.largeTitle); Text("I feel okay, somewhere near the middle").foregroundColor(.white) }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.yellow.opacity(0.3))
                                    .cornerRadius(12)
                            }
                            Button {
                                userMood = "🔴"
                                UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                showMoodPicker = false
                            } label: {
                                HStack { Text("🔴").font(.largeTitle); Text("Not very focused, not good").foregroundColor(.white) }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.3))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.top, 8)
                        Button("Cancel") { showMoodPicker = false }
                            .foregroundColor(.purple)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.black.ignoresSafeArea())
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            ToDoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(1)

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(2)

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(3)

            StudyHomeView()
                .tabItem {
                    Label("Study", systemImage: "book.closed")
                }
                .tag(5)
        }
        
        VStack {
            Spacer()
            HStack {
                FloatingTimerIndicator()
                    .padding(.leading, 20)
                    .padding(.bottom, 100) 
                Spacer()
            }
        }
        }
        .fullScreenCover(isPresented: $showTimerCelebration) {
            CongratulationsView(
                title: "Amazing Work!",
                message: timerManager.selectedTasks.isEmpty 
                    ? "You've completed your focus session. Time for a break!"
                    : "You focused on \(timerManager.selectedTasks.count) task\(timerManager.selectedTasks.count == 1 ? "" : "s"). Great job!"
            )
            .onDisappear {
                timerManager.resetTimer()
                timerManager.showingCompletionAlert = false
            }
        }
        .onChange(of: timerManager.showingCompletionAlert) { isShowing in
            if isShowing {
                showTimerCelebration = true
            }
        }
    }

    @ViewBuilder
    private func homeDestination(for id: UUID, kind: String) -> some View {
        switch kind {
        case "Flashcards":
            if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
               let sets = try? JSONDecoder().decode([FlashcardSet].self, from: data),
               let set = sets.first(where: { $0.id == id }) {
                FlashcardsView(selectedSetID: set.id)
            } else {
                FlashcardsView()
            }
        case "Study Guides":
            if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
               let guides = try? JSONDecoder().decode([StudyGuide].self, from: data),
               let guide = guides.first(where: { $0.id == id }) {
                StudyGuideDetailView(guide: guide)
            } else {
                StudyGuidesView()
            }
        case "Practice Tests":
            if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
               let tests = try? JSONDecoder().decode([PracticeTest].self, from: data),
               let test = tests.first(where: { $0.id == id }) {
                PracticeTestDetailLoaderView(testID: test.id)
            } else {
                PracticeTestsView()
            }
        default:
            FlashcardsView()
        }
    }
}

#Preview {
    NavigationView {
        HomePageView()
    }
}
