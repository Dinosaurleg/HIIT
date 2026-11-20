//
//  HIITTimer.swift
//  HIIT
//
//  Created by Jemin Shin on 4/17/25.
//

import Foundation
import SwiftData

@Model
final class HIITTimer {
    var name: String
    // Durations are stored in minutes.
    var warmUp: Double
    var coolDown: Double
    var restPeriod: Double
    var workPeriod: Double
    var rounds: Int = 8
    var countdownSoundEnabled: Bool = true
    
    init(
        name: String,
        warmUp: Double = 0.0,
        coolDown: Double = 0.0,
        restPeriod: Double = 0.0,
        workPeriod: Double = 0.0,
        rounds: Int = 8
    ) {
        self.name = name
        self.warmUp = warmUp
        self.coolDown = coolDown
        self.restPeriod = restPeriod
        self.workPeriod = workPeriod
        self.rounds = rounds
    }
    
    private func setWarmUp(warmUp: Double) {
        self.warmUp = warmUp
    }
    
    private func setCoolDown(coolDown: Double) {
        self.coolDown = coolDown
    }
    
    private func setRestPeriod(restPeriod: Double) {
        self.restPeriod = restPeriod
    }
    
    private func setWorkPeriod(workPeriod: Double) {
        self.workPeriod = workPeriod
    }
}
