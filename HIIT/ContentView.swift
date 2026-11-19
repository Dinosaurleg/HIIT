//
//  ContentView.swift
//  HIIT
//
//  Created by Jemin Shin on 4/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var timers: [HIITTimer]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(timers) { timer in
                    NavigationLink {
                        Text("Hello")
                    } label: {
                        Text(timer.name)
                    }
                }
                .onDelete(perform: deleteTimers)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: {
//                        @State var username: String = ""
//                        var body: some View {
//                            TextField(
//                                "User name (email address)",
//                                text: $username
//                            )
//                            .focused($emailFieldIsFocused)
//                            .onSubmit {
//                                validate(name: username)
//                            }
//                            .textInputAutocapitalization(.never)
//                            .disableAutocorrection(true)
//                            .border(.secondary)
//
//
//                            Text(username)
//                                .foregroundColor(emailFieldIsFocused ? .red : .blue)
//                        }
                    }) {
                        Label("Add Timer", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addTimer() {
        withAnimation {
            let newItem = HIITTimer(name: "TestName")
            modelContext.insert(newItem)
        }
    }

    private func deleteTimers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(timers[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HIITTimer.self, inMemory: true)
}
