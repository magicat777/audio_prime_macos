//
//  BeatDetector.swift
//  AudioPrime
//
//  Real-time BPM detection and beat tracking using autocorrelation
//  Ported from AUDIO_PRIME Linux implementation
//

import Foundation

// MARK: - Beat Detection Result
struct BeatInfo {
    var bpm: Float           // Current tempo estimate
    var confidence: Float    // 0-1 confidence in tempo estimate
    var beat: Bool           // True if a beat occurred this frame
    var beatPhase: Float     // 0-1 position within current beat
    var beatStrength: Float  // Strength of current beat (0-1)
    var downbeat: Bool       // True if this is likely a downbeat
    var beatCount: Int       // Running count of detected beats
}

// MARK: - Onset Detection Band
private struct OnsetBand {
    var name: String
    var minBar: Int
    var maxBar: Int
    var weight: Float
    var prevEnergy: Float = 0
    var threshold: Float
    var energyHistory: [Float]
    var historyPos: Int = 0
    var meanEnergy: Float = 0
    var energySum: Float = 0
}

// MARK: - Constants
private let ONSET_THRESHOLD_BASE: Float = 0.015
private let ONSET_DECAY: Float = 0.95
private let ONSET_ADAPT_RATE: Float = 0.3

private let MIN_BPM: Float = 60
private let MAX_BPM: Float = 180
private let TEMPO_HISTORY_SIZE = 8
private let CORRELATION_WINDOW = 128

private let BEAT_PREDICT_WINDOW: Float = 0.08
private let PHASE_CORRECTION_RATE: Float = 0.15

private let SPECTRUM_BARS = 512
private let SPECTRUM_MIN_FREQ: Float = 20
private let SPECTRUM_MAX_FREQ: Float = 20000

private let ENERGY_HISTORY_SIZE = 30
private let ONSET_HISTORY_SIZE = 512

private let SILENCE_THRESHOLD: Float = 0.01
private let SILENCE_RESET_MS: Double = 3000

// MARK: - Beat Detector
class BeatDetector {
    // Onset detection bands
    private var bands: [OnsetBand]
    private var onsetHistory: [Float]
    private var onsetWritePos: Int = 0

    // Tempo estimation
    private var currentBPM: Float = 120
    private var tempoHistory: [Float] = []
    private var tempoConfidence: Float = 0
    private var lastTempoUpdate: Date = Date.distantPast
    private let tempoUpdateInterval: TimeInterval = 0.75

    // Beat tracking
    private var beatPhase: Float = 0
    private var lastBeatTime: Date = Date()
    private var beatInterval: TimeInterval = 0.5  // 120 BPM default
    private var beatCount: Int = 0
    private var downbeatCounter: Int = 0

    // Confidence smoothing
    private var smoothedConfidence: Float = 0
    private let confidenceSmoothUp: Float = 0.10
    private let confidenceSmoothDown: Float = 0.01
    private var stableTempoCount: Int = 0
    private var lockedBPM: Float = 0
    private let lockThreshold: Float = 0.65
    private let stableTempoTolerance: Float = 0.05

    // Frame timing
    private var lastProcessTime: Date = Date()
    private var frameTimeMs: Double = 16.67

    // Silence detection
    private var silenceStartTime: Date?

    // Strength smoothing
    private var smoothedStrength: Float = 0
    private let strengthSmoothUp: Float = 0.3    // Fast attack
    private let strengthSmoothDown: Float = 0.08 // Slower decay

    init() {
        // Initialize frequency bands for onset detection
        bands = [
            OnsetBand(
                name: "kick",
                minBar: Self.freqToBar(40),
                maxBar: Self.freqToBar(120),
                weight: 2.5,
                threshold: ONSET_THRESHOLD_BASE,
                energyHistory: Array(repeating: 0, count: ENERGY_HISTORY_SIZE)
            ),
            OnsetBand(
                name: "snare",
                minBar: Self.freqToBar(120),
                maxBar: Self.freqToBar(400),
                weight: 1.5,
                threshold: ONSET_THRESHOLD_BASE,
                energyHistory: Array(repeating: 0, count: ENERGY_HISTORY_SIZE)
            ),
            OnsetBand(
                name: "hihat",
                minBar: Self.freqToBar(4000),
                maxBar: Self.freqToBar(12000),
                weight: 0.8,
                threshold: ONSET_THRESHOLD_BASE,
                energyHistory: Array(repeating: 0, count: ENERGY_HISTORY_SIZE)
            )
        ]

        // Onset history for autocorrelation
        onsetHistory = Array(repeating: 0, count: ONSET_HISTORY_SIZE)
    }

    // Convert frequency to spectrum bar index (logarithmic mapping)
    private static func freqToBar(_ freq: Float) -> Int {
        let t = log(freq / SPECTRUM_MIN_FREQ) / log(SPECTRUM_MAX_FREQ / SPECTRUM_MIN_FREQ)
        return max(0, min(SPECTRUM_BARS - 1, Int(t * Float(SPECTRUM_BARS - 1))))
    }

    // MARK: - Main Processing
    func process(spectrum: [Float]) -> BeatInfo {
        let now = Date()

        // Calculate frame time
        frameTimeMs = now.timeIntervalSince(lastProcessTime) * 1000
        if frameTimeMs <= 0 || frameTimeMs > 100 {
            frameTimeMs = 16.67  // Default to 60fps
        }
        lastProcessTime = now

        // 1. Onset Detection
        var totalOnset: Float = 0
        var kickOnset: Float = 0
        var totalEnergy: Float = 0
        var totalFlux: Float = 0

        for i in 0..<bands.count {
            let energy = calculateBandEnergy(spectrum: spectrum, minBin: bands[i].minBar, maxBin: bands[i].maxBar)
            totalEnergy += energy

            // Update running sum for mean calculation
            let oldEnergy = bands[i].energyHistory[bands[i].historyPos]
            bands[i].energySum = bands[i].energySum - oldEnergy + energy
            bands[i].energyHistory[bands[i].historyPos] = energy
            bands[i].historyPos = (bands[i].historyPos + 1) % ENERGY_HISTORY_SIZE

            // Calculate mean energy
            bands[i].meanEnergy = bands[i].energySum / Float(ENERGY_HISTORY_SIZE)

            // Spectral flux
            let flux = max(0, energy - bands[i].prevEnergy)
            totalFlux += flux * bands[i].weight

            // Deviation from mean
            let deviation = max(0, energy - bands[i].meanEnergy * 1.3)

            // Combined onset
            let rawOnset = flux * 0.7 + deviation * 0.3

            // Apply adaptive threshold
            if rawOnset > bands[i].threshold {
                let onsetValue = (rawOnset - bands[i].threshold) * bands[i].weight
                totalOnset += onsetValue

                if bands[i].name == "kick" {
                    kickOnset = onsetValue
                }

                // Raise threshold after detection
                bands[i].threshold = max(ONSET_THRESHOLD_BASE,
                                         bands[i].threshold + rawOnset * ONSET_ADAPT_RATE)
            } else {
                // Decay threshold
                bands[i].threshold *= ONSET_DECAY
                bands[i].threshold = max(ONSET_THRESHOLD_BASE, bands[i].threshold)
            }

            bands[i].prevEnergy = energy
        }

        // Normalize values
        let onsetStrength = min(1, totalOnset * 2)
        let fluxSignal = min(1, totalFlux * 5)
        let avgEnergy = totalEnergy / Float(bands.count)
        let rawStrength = min(1, fluxSignal * 0.4 + avgEnergy * 1.2)

        // Apply asymmetric smoothing to strength (fast attack, slow decay)
        if rawStrength > smoothedStrength {
            smoothedStrength += (rawStrength - smoothedStrength) * strengthSmoothUp
        } else {
            smoothedStrength += (rawStrength - smoothedStrength) * strengthSmoothDown
        }
        let displayStrength = smoothedStrength

        // Silence detection - full reset after 3 seconds of no audio
        if totalEnergy < SILENCE_THRESHOLD {
            if silenceStartTime == nil {
                silenceStartTime = now
            } else if now.timeIntervalSince(silenceStartTime!) * 1000 > SILENCE_RESET_MS {
                // Full reset - ready for new track
                reset()
                // Keep silence start time so we don't keep resetting
                silenceStartTime = now
            }
        } else {
            silenceStartTime = nil
        }

        // Store flux in onset history
        onsetHistory[onsetWritePos] = fluxSignal
        onsetWritePos = (onsetWritePos + 1) % ONSET_HISTORY_SIZE

        // 2. Tempo Estimation (periodic update)
        if now.timeIntervalSince(lastTempoUpdate) > tempoUpdateInterval {
            updateTempo()
            lastTempoUpdate = now
        }

        // 3. Beat Tracking
        let beatResult = trackBeat(now: now, onsetStrength: onsetStrength, kickOnset: kickOnset)

        return BeatInfo(
            bpm: round(currentBPM),
            confidence: tempoConfidence,
            beat: beatResult.beat,
            beatPhase: beatPhase,
            beatStrength: displayStrength,
            downbeat: beatResult.downbeat,
            beatCount: beatCount
        )
    }

    // MARK: - Band Energy Calculation
    private func calculateBandEnergy(spectrum: [Float], minBin: Int, maxBin: Int) -> Float {
        var energy: Float = 0
        let binCount = min(maxBin, spectrum.count) - minBin

        guard binCount > 0 else { return 0 }

        for i in minBin..<min(maxBin, spectrum.count) {
            energy += spectrum[i] * spectrum[i]
        }

        return sqrt(energy / Float(binCount))
    }

    // MARK: - Tempo Estimation via Autocorrelation
    private func updateTempo() {
        guard frameTimeMs > 0 else { return }

        // Calculate lag range for BPM detection
        let minLag = Int((60.0 / Double(MAX_BPM)) * (1000.0 / frameTimeMs))
        let maxLag = Int((60.0 / Double(MIN_BPM)) * (1000.0 / frameTimeMs))

        guard maxLag > minLag else { return }

        var bestLag = 0
        var bestCorr: Float = 0

        let windowSize = min(CORRELATION_WINDOW, ONSET_HISTORY_SIZE - maxLag)
        let stride = 2

        // Calculate autocorrelation for each lag
        for lag in minLag...min(maxLag, ONSET_HISTORY_SIZE / 2) {
            var correlation: Float = 0
            var count = 0

            var i = 0
            while i < windowSize {
                let idx1 = (onsetWritePos - 1 - i + ONSET_HISTORY_SIZE) % ONSET_HISTORY_SIZE
                let idx2 = (onsetWritePos - 1 - i - lag + ONSET_HISTORY_SIZE) % ONSET_HISTORY_SIZE
                correlation += onsetHistory[idx1] * onsetHistory[idx2]
                count += 1
                i += stride
            }

            if count > 0 {
                correlation /= Float(count)

                // Weight towards common tempos (85-135 BPM)
                let bpmAtLag = Float(60.0 * 1000.0 / (Double(lag) * frameTimeMs))
                if bpmAtLag >= 85 && bpmAtLag <= 135 {
                    correlation *= 1.2
                }

                if correlation > bestCorr {
                    bestCorr = correlation
                    bestLag = lag
                }
            }
        }

        if bestLag > 0 && bestCorr > 0.01 {
            var newBPM = Float(60.0 * 1000.0 / (Double(bestLag) * frameTimeMs))

            // Octave error correction
            let bpmRatio = newBPM / currentBPM
            if bpmRatio > 1.8 && bpmRatio < 2.2 {
                newBPM /= 2
            } else if bpmRatio > 0.45 && bpmRatio < 0.55 {
                newBPM *= 2
            }

            // Clamp to valid range
            newBPM = max(MIN_BPM, min(MAX_BPM, newBPM))

            // Add to history
            tempoHistory.append(newBPM)
            if tempoHistory.count > TEMPO_HISTORY_SIZE {
                tempoHistory.removeFirst()
            }

            // Median filter for stability
            if !tempoHistory.isEmpty {
                let sorted = tempoHistory.sorted()
                currentBPM = sorted[sorted.count / 2]
            }

            // Update beat interval
            beatInterval = 60.0 / Double(currentBPM)

            // Calculate confidence
            updateConfidence(correlationScore: min(1, bestCorr * 15))
        }
    }

    private func updateConfidence(correlationScore: Float) {
        var rawConfidence: Float = 0

        if tempoHistory.count >= 2 {
            let sorted = tempoHistory.sorted()
            let median = sorted[sorted.count / 2]

            // Calculate stability
            var stableCount = 0
            var stabilitySum: Float = 0
            for bpm in tempoHistory {
                let deviation = abs(bpm - median) / median
                if deviation < 0.15 {
                    stableCount += 1
                    stabilitySum += 1 - deviation * 3
                }
            }

            let stabilityScore = tempoHistory.isEmpty ? 0 :
                (Float(stableCount) / Float(tempoHistory.count)) * (stabilitySum / max(1, Float(stableCount)))

            let historyFactor = min(1, Float(tempoHistory.count) / 4)

            rawConfidence = min(1,
                correlationScore * 0.35 +
                stabilityScore * historyFactor * 0.40 +
                historyFactor * 0.25
            )
        } else {
            rawConfidence = min(0.6, correlationScore * 0.6)
        }

        // Track tempo stability
        let tempoChange = lockedBPM > 0 ? abs(currentBPM - lockedBPM) / lockedBPM : 0

        if tempoChange < stableTempoTolerance {
            stableTempoCount += 1
        } else {
            stableTempoCount = max(0, stableTempoCount - 2)
            if smoothedConfidence > lockThreshold {
                lockedBPM = currentBPM
            }
        }

        if smoothedConfidence >= lockThreshold && lockedBPM == 0 {
            lockedBPM = currentBPM
        }

        // Stability bonus
        let stabilityBonus = min(0.15, Float(stableTempoCount) * 0.0075)
        let targetConfidence = min(1, rawConfidence + stabilityBonus)

        // Asymmetric smoothing
        if targetConfidence > smoothedConfidence {
            smoothedConfidence += (targetConfidence - smoothedConfidence) * confidenceSmoothUp
        } else {
            let decayRate = (lockedBPM > 0 && tempoChange < stableTempoTolerance)
                ? confidenceSmoothDown * 0.5
                : confidenceSmoothDown
            smoothedConfidence += (targetConfidence - smoothedConfidence) * decayRate
        }

        tempoConfidence = smoothedConfidence
    }

    // MARK: - Beat Tracking
    private func trackBeat(now: Date, onsetStrength: Float, kickOnset: Float) -> (beat: Bool, downbeat: Bool) {
        // Update phase
        let elapsed = now.timeIntervalSince(lastBeatTime)
        beatPhase = Float(elapsed.truncatingRemainder(dividingBy: beatInterval) / beatInterval)

        // Predict beat when phase wraps
        let predictedBeat = elapsed >= beatInterval

        // Check for onset near predicted position
        let nearPrediction = beatPhase > 1 - BEAT_PREDICT_WINDOW || beatPhase < BEAT_PREDICT_WINDOW
        let strongOnset = onsetStrength > 0.3 || kickOnset > 0.2

        var beat = false
        var downbeat = false

        if predictedBeat || (nearPrediction && strongOnset) {
            beat = true
            beatCount += 1
            downbeatCounter += 1

            // Adjust phase based on onset
            if strongOnset && !predictedBeat {
                let phaseError = beatPhase > 0.5 ? beatPhase - 1 : beatPhase
                lastBeatTime = now.addingTimeInterval(-Double(phaseError) * beatInterval * Double(PHASE_CORRECTION_RATE))
            } else {
                lastBeatTime = now
            }

            // Downbeat detection (4/4 time)
            if downbeatCounter >= 4 {
                downbeatCounter = 0
                downbeat = true
            }

            beatPhase = 0
        }

        return (beat, downbeat)
    }

    // MARK: - Reset
    func reset() {
        onsetHistory = Array(repeating: 0, count: ONSET_HISTORY_SIZE)
        onsetWritePos = 0
        tempoHistory = []
        currentBPM = 0  // Show "---" until new tempo detected
        tempoConfidence = 0
        smoothedConfidence = 0
        smoothedStrength = 0
        stableTempoCount = 0
        lockedBPM = 0
        beatPhase = 0
        lastBeatTime = Date()
        beatCount = 0
        downbeatCounter = 0
        // Don't reset silenceStartTime here - let caller manage it

        for i in 0..<bands.count {
            bands[i].prevEnergy = 0
            bands[i].threshold = ONSET_THRESHOLD_BASE
            bands[i].energyHistory = Array(repeating: 0, count: ENERGY_HISTORY_SIZE)
            bands[i].historyPos = 0
            bands[i].meanEnergy = 0
            bands[i].energySum = 0
        }
    }

    /// Check if currently in silence/reset state
    var isInSilence: Bool {
        return silenceStartTime != nil
    }
}
