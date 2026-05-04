//
//  ContentView.swift
//  tabletennislevelsapp
//
//  Created by Demitri Booker on 4/20/26.
//
import SwiftUI
import Combine

struct ContentView: View {
    var body: some View {
        TableTennisGameView()
    }
}

struct TableTennisGameView: View {
    private let totalLevels = 5
    private let pointsToAdvance = 5

    @State private var timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    @State private var courtSize = CGSize.zero
    @State private var gameStarted = false
    @State private var gamePaused = false
    @State private var gameOver = false
    @State private var playerWon = false

    @State private var level = 1
    @State private var playerScore = 0
    @State private var aiScore = 0

    @State private var ballPosition = CGPoint.zero
    @State private var ballVelocity = CGVector.zero
    @State private var playerPaddleX: CGFloat = 0
    @State private var aiPaddleX: CGFloat = 0
    @State private var lastUpdate = Date()

    @State private var freezeAITimeRemaining: Double = 0
    @State private var enlargePlayerTimeRemaining: Double = 0
    @State private var playerPowerShotsRemaining: Int = 0

    var body: some View {
        GeometryReader { outerGeo in
            let screenSize = outerGeo.size

            VStack(spacing: 12) {
                header
                    .padding(.horizontal)
                    .padding(.top, 16)

                powerBar
                    .padding(.horizontal)

                GeometryReader { courtGeo in
                    let size = courtGeo.size

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                        Path { path in
                            path.move(to: CGPoint(x: size.width / 2.0, y: 24.0))
                            path.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 24.0))
                        }
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [8, 10]))

                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.blue.opacity(0.25))
                                .frame(height: 72)
                                .padding(.horizontal, 12)
                                .overlay(
                                    Text("DRAG THE BLUE PADDLE")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.bottom, 6),
                                    alignment: .bottom
                                )
                                .padding(.bottom, 6)
                        }

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: paddleWidth, height: paddleHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: Color.red.opacity(0.35), radius: 6)
                            .position(x: aiPaddleX, y: aiY(in: size))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .frame(width: playerPaddleDisplayWidth, height: playerPaddleHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: Color.blue.opacity(0.45), radius: 8)
                            .position(x: playerPaddleX, y: playerY(in: size))
                            .gesture(playerDragGesture(courtWidth: size.width))

                        Circle()
                            .fill(Color.yellow)
                            .frame(width: ballSize, height: ballSize)
                            .position(ballPosition)
                            .shadow(color: Color.yellow.opacity(0.55), radius: 10)

                        if !gameStarted && !gameOver && !playerWon {
                            overlayCard(
                                title: "Table Tennis",
                                subtitle: "Drag the blue paddle. Use power-ups to beat the AI.",
                                buttonTitle: "Start Game",
                                action: startGame
                            )
                        }

                        if gamePaused {
                            pauseMenu
                        }

                        if gameOver {
                            overlayCard(
                                title: "Game Over",
                                subtitle: "The AI won this round. Try again.",
                                buttonTitle: "Play Again",
                                action: resetGame
                            )
                        }

                        if playerWon {
                            overlayCard(
                                title: "You Win!",
                                subtitle: "You beat all 5 levels.",
                                buttonTitle: "Play Again",
                                action: resetGame
                            )
                        }
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .onAppear {
                        setupIfNeeded(for: size)
                    }
                    .onChange(of: size.width) { _ in
                        setupIfNeeded(for: size)
                    }
                    .onChange(of: size.height) { _ in
                        setupIfNeeded(for: size)
                    }
                    .onReceive(timer) { _ in
                        update(in: size)
                    }
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.03, green: 0.07, blue: 0.11), Color(red: 0.05, green: 0.14, blue: 0.20)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onAppear {
                setupIfNeeded(for: screenSize)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Table Tennis")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("Level \(level)/\(totalLevels)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14), in: Capsule())

                Button(action: togglePause) {
                    Image(systemName: gamePaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .padding(.leading, 8)
            }

            HStack {
                statPill(title: "You", value: playerScore)
                Spacer()
                statPill(title: "AI", value: aiScore)
            }
        }
    }

    private var powerBar: some View {
        HStack(spacing: 10) {
            powerButton(title: freezeAITimeRemaining > 0 ? "Freeze AI" : "Freeze AI",
                        systemImage: "snowflake",
                        isActive: freezeAITimeRemaining > 0,
                        disabled: freezeAITimeRemaining > 0) {
                activateFreezeAI()
            }

            powerButton(title: enlargePlayerTimeRemaining > 0 ? "Big Paddle" : "Big Paddle",
                        systemImage: "arrow.left.and.right",
                        isActive: enlargePlayerTimeRemaining > 0,
                        disabled: enlargePlayerTimeRemaining > 0) {
                activateBigPaddle()
            }

            powerButton(title: playerPowerShotsRemaining > 0 ? "Power Shot \(playerPowerShotsRemaining)" : "Power Shot",
                        systemImage: "bolt.fill",
                        isActive: playerPowerShotsRemaining > 0,
                        disabled: playerPowerShotsRemaining > 0) {
                activatePowerShot()
            }
        }
    }

    private func powerButton(title: String, systemImage: String, isActive: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(disabled ? Color.white.opacity(0.45) : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.green.opacity(0.28) : Color.white.opacity(0.12), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .disabled(disabled)
    }

    private var pauseMenu: some View {
        VStack(spacing: 16) {
            Text("Paused")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text("Take a break and come back ready.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))

            Button(action: togglePause) {
                Text("Resume")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
            }

            Button(action: resetGame) {
                Text("Restart")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
        }
        .padding(28)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding()
    }

    private func statPill(title: String, value: Int) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text("\(value)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func overlayCard(title: String, subtitle: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
            }
        }
        .padding(28)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding()
    }

    private var paddleWidth: CGFloat {
        if enlargePlayerTimeRemaining > 0 {
            return max(96.0, 175.0 - CGFloat(level - 1) * 12.0)
        }
        return max(78.0, 150.0 - CGFloat(level - 1) * 16.0)
    }

    private var playerPaddleDisplayWidth: CGFloat {
        paddleWidth
    }

    private var paddleHeight: CGFloat { max(12.0, 18.0 - CGFloat(level - 1) * 1.0) }
    private var playerPaddleHeight: CGFloat { paddleHeight }
    private var ballSize: CGFloat { max(10.0, 16.0 - CGFloat(level - 1) * 1.0) }
    private var playerPaddleHalfWidth: CGFloat { playerPaddleDisplayWidth / 2.0 }
    private var aiPaddleHalfWidth: CGFloat { paddleWidth / 2.0 }

    private func aiY(in size: CGSize) -> CGFloat { 60.0 }
    private func playerY(in size: CGSize) -> CGFloat { max(92.0, size.height - 92.0) }

    private func setupIfNeeded(for size: CGSize) {
        guard size.width > 0.0, size.height > 0.0 else { return }
        let firstSetup = courtSize == .zero
        courtSize = size

        if playerPaddleX == 0 { playerPaddleX = size.width / 2.0 }
        if aiPaddleX == 0 { aiPaddleX = size.width / 2.0 }

        if firstSetup {
            resetBall(towardPlayer: Bool.random())
        }
    }

    private func startGame() {
        gameStarted = true
        gamePaused = false
        gameOver = false
        playerWon = false
        lastUpdate = Date()
        resetBall(towardPlayer: Bool.random())
    }

    private func resetGame() {
        level = 1
        playerScore = 0
        aiScore = 0
        gamePaused = false
        gameOver = false
        playerWon = false
        gameStarted = true
        freezeAITimeRemaining = 0
        enlargePlayerTimeRemaining = 0
        playerPowerShotsRemaining = 0
        resetBall(towardPlayer: Bool.random())
    }

    private func togglePause() {
        guard gameStarted && !gameOver && !playerWon else { return }
        gamePaused.toggle()
        lastUpdate = Date()
    }

    private func playerDragGesture(courtWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard gameStarted && !gameOver && !playerWon else { return }
                playerPaddleX = clamp(value.location.x, playerPaddleHalfWidth, courtWidth - playerPaddleHalfWidth)
            }
    }

    private func resetBall(towardPlayer: Bool) {
        guard courtSize != .zero else { return }
        ballPosition = CGPoint(x: courtSize.width / 2.0, y: courtSize.height / 2.0)

        let horizontal = CGFloat.random(in: -0.30...0.30)
        let speed = ballSpeed
        let vertical: CGFloat = towardPlayer ? 1.0 : -1.0
        ballVelocity = CGVector(dx: speed * horizontal, dy: speed * vertical)
    }

    private func activateFreezeAI() {
        freezeAITimeRemaining = 2.0
    }

    private func activateBigPaddle() {
        enlargePlayerTimeRemaining = 8.0
    }

    private func activatePowerShot() {
        playerPowerShotsRemaining = 1
    }

    private func update(in size: CGSize) {
        guard gameStarted && !gameOver && !playerWon else { return }

        let now = Date()
        let dt = min(now.timeIntervalSince(lastUpdate), 1.0 / 30.0)
        lastUpdate = now

        if gamePaused {
            return
        }

        if freezeAITimeRemaining > 0 {
            freezeAITimeRemaining = max(0, freezeAITimeRemaining - dt)
        }
        if enlargePlayerTimeRemaining > 0 {
            enlargePlayerTimeRemaining = max(0, enlargePlayerTimeRemaining - dt)
        }

        updateAI(dt: dt, size: size)
        updateBall(dt: dt, size: size)
    }

    private func updateAI(dt: TimeInterval, size: CGSize) {
        if freezeAITimeRemaining > 0 {
            return
        }

        let targetX = clamp(ballPosition.x + aiPredictiveBias, aiPaddleHalfWidth, size.width - aiPaddleHalfWidth)
        let delta = targetX - aiPaddleX
        let step = CGFloat(aiReactionSpeed * dt)
        aiPaddleX += delta * min(1.0, step)
        aiPaddleX = clamp(aiPaddleX, aiPaddleHalfWidth, size.width - aiPaddleHalfWidth)
    }

    private var aiPredictiveBias: CGFloat {
        let farLevel = CGFloat(max(0, level - 1))
        return CGFloat.random(in: -5.0...5.0) * max(0.0, 3.0 - farLevel)
    }

    private var aiReactionSpeed: CGFloat {
        switch level {
        case 1: return 4.8
        case 2: return 6.0
        case 3: return 7.8
        case 4: return 9.2
        default: return 11.0
        }
    }

    private var ballSpeed: CGFloat {
        switch level {
        case 1: return 290.0
        case 2: return 340.0
        case 3: return 390.0
        case 4: return 450.0
        default: return 520.0
        }
    }

    private func updateBall(dt: TimeInterval, size: CGSize) {
        ballPosition.x += ballVelocity.dx * CGFloat(dt)
        ballPosition.y += ballVelocity.dy * CGFloat(dt)

        if ballPosition.x <= ballSize / 2.0 {
            ballPosition.x = ballSize / 2.0
            ballVelocity.dx *= -1.0
        } else if ballPosition.x >= size.width - ballSize / 2.0 {
            ballPosition.x = size.width - ballSize / 2.0
            ballVelocity.dx *= -1.0
        }

        let aiYValue = aiY(in: size)
        if ballVelocity.dy < 0.0,
           ballPosition.y - ballSize / 2.0 <= aiYValue + paddleHeight / 2.0,
           ballPosition.y - ballSize / 2.0 >= aiYValue - paddleHeight / 2.0 - 8.0,
           abs(ballPosition.x - aiPaddleX) <= aiPaddleHalfWidth + ballSize / 2.0 {
            hitPaddle(isPlayer: false)
            ballPosition.y = aiYValue + paddleHeight / 2.0 + ballSize / 2.0
        }

        let playerYValue = playerY(in: size)
        if ballVelocity.dy > 0.0,
           ballPosition.y + ballSize / 2.0 >= playerYValue - playerPaddleHeight / 2.0,
           ballPosition.y + ballSize / 2.0 <= playerYValue + playerPaddleHeight / 2.0 + 8.0,
           abs(ballPosition.x - playerPaddleX) <= playerPaddleHalfWidth + ballSize / 2.0 {
            hitPaddle(isPlayer: true)
            ballPosition.y = playerYValue - playerPaddleHeight / 2.0 - ballSize / 2.0

            if playerPowerShotsRemaining > 0 {
                ballVelocity.dx *= 1.25
                ballVelocity.dy *= 1.15
                playerPowerShotsRemaining = 0
            }
        }

        if ballPosition.y > size.height + 40.0 {
            aiScore += 1
            resetBall(towardPlayer: false)
            if aiScore >= pointsToAdvance {
                gameOver = true
            }
        }

        if ballPosition.y < -40.0 {
            playerScore += 1
            resetBall(towardPlayer: true)
            if playerScore >= pointsToAdvance {
                if level >= totalLevels {
                    playerWon = true
                } else {
                    level += 1
                    playerScore = 0
                    aiScore = 0
                    resetBall(towardPlayer: Bool.random())
                }
            }
        }
    }

    private func hitPaddle(isPlayer: Bool) {
        let speed = ballSpeed + CGFloat(level - 1) * 26.0
        let paddleX = isPlayer ? playerPaddleX : aiPaddleX
        let halfWidth = isPlayer ? playerPaddleHalfWidth : aiPaddleHalfWidth
        let offset = (ballPosition.x - paddleX) / max(halfWidth, 1.0)
        let chaos = CGFloat.random(in: -14.0...14.0) * CGFloat(level - 1)
        let yDirection: CGFloat = isPlayer ? -1.0 : 1.0
        ballVelocity = CGVector(dx: offset * speed * 0.95 + chaos, dy: speed * 0.90 * yDirection)
    }

    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portrait)
    }
}
