//
//  ViewController.swift
//  AudioTestSwift
//
//  Created by Gospel Apps on 11/30/15.
//  Copyright © 2015 Gospel Apps. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - Configuration

    // Plain HTTP on purpose: this host does not serve valid TLS.
    // See the scoped NSExceptionDomains entry in Info.plist.
    private static let remoteURLString = "http://www.noiseaddicts.com/samples_1w72b820/181.mp3"
    private static let localFileName = "[Replace-Before-Flight]"
    private static let localFileExtension = "mp3"

    // MARK: - Player state

    private var player: AVPlayer?

    /// Holds the block-based KVO tokens for the *current* player/item.
    /// Invalidated before a new player is created and in deinit, which is
    /// what prevents the classic "observer still attached at dealloc" crash.
    private var observations: [NSKeyValueObservation] = []

    // MARK: - UI

    private let instructionsLabel = UILabel()
    private let remoteSetupButton = UIButton(type: .system)
    private let localSetupButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        configureAudioSession()
        setupUI()
        setPlaybackControlsEnabled(false)
        showStatus("No audio loaded.")
    }

    deinit {
        invalidateObservations()
    }

    // MARK: - Setup

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func setupUI() {
        instructionsLabel.text = "Load audio from a URL or from the app bundle, then press Play."
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textAlignment = .center

        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 14)

        remoteSetupButton.setTitle("Setup Audio From Url", for: .normal)
        remoteSetupButton.addTarget(self, action: #selector(setupRemoteAudioTapped(_:)), for: .touchUpInside)

        localSetupButton.setTitle("Setup Audio From Local File", for: .normal)
        localSetupButton.addTarget(self, action: #selector(setupLocalAudioTapped(_:)), for: .touchUpInside)

        playButton.setTitle("Play", for: .normal)
        playButton.addTarget(self, action: #selector(playTapped(_:)), for: .touchUpInside)

        pauseButton.setTitle("Pause", for: .normal)
        pauseButton.addTarget(self, action: #selector(pauseTapped(_:)), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            instructionsLabel, remoteSetupButton, localSetupButton,
            playButton, pauseButton, statusLabel
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func setupRemoteAudioTapped(_ sender: UIButton) {
        guard let url = URL(string: ViewController.remoteURLString) else {
            showStatus("Invalid remote URL.", isError: true)
            return
        }
        showStatus("Loading remote audio\u{2026}")
        setupPlayer(with: url)
    }

    @objc private func setupLocalAudioTapped(_ sender: UIButton) {
        guard let url = Bundle.main.url(forResource: ViewController.localFileName,
                                        withExtension: ViewController.localFileExtension) else {
            setPlaybackControlsEnabled(false)
            showStatus("\(ViewController.localFileName).\(ViewController.localFileExtension) is not in the app bundle. "
                     + "Add it to the AudioTestSwift target.", isError: true)
            return
        }
        showStatus("Loading local audio\u{2026}")
        setupPlayer(with: url)
    }

    @objc private func playTapped(_ sender: UIButton) {
        player?.play()
        showStatus("Playing.")
    }

    @objc private func pauseTapped(_ sender: UIButton) {
        player?.pause()
        showStatus("Paused.")
    }

    // MARK: - Player

    private func setupPlayer(with url: URL) {
        // Tear down the previous player *and* its observers before replacing it.
        invalidateObservations()
        player?.pause()
        player = nil
        setPlaybackControlsEnabled(false)

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        // Item status is where load/decode/ATS failures actually surface.
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            self?.handleItemStatus(item)
        })

        // Player status, matching the original demo's observation.
        observations.append(newPlayer.observe(\.status, options: [.initial, .new]) { [weak self] player, _ in
            self?.handlePlayerStatus(player)
        })
    }

    private func handleItemStatus(_ item: AVPlayerItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
                self.setPlaybackControlsEnabled(true)
                self.showStatus("Ready to play.")
            case .failed:
                self.setPlaybackControlsEnabled(false)
                let message = item.error?.localizedDescription ?? "Unknown error"
                self.showStatus("Failed to load audio: \(message)", isError: true)
            default:
                self.showStatus("Loading\u{2026}")
            }
        }
    }

    private func handlePlayerStatus(_ player: AVPlayer) {
        switch player.status {
        case .readyToPlay: print("AVPlayer status: readyToPlay")
        case .failed:      print("AVPlayer status: failed - \(player.error?.localizedDescription ?? "unknown")")
        default:           print("AVPlayer status: unknown")
        }
    }

    private func invalidateObservations() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
    }

    // MARK: - UI helpers

    private func setPlaybackControlsEnabled(_ enabled: Bool) {
        playButton.isEnabled = enabled
        pauseButton.isEnabled = enabled
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .red : .darkGray
    }
}
