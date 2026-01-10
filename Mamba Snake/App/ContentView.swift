import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var scene: GameScene = {
        let sc = GameScene()
        sc.scaleMode = .resizeFill
        return sc
    }()

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    scene.size = proxy.size
                }
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height

                            if abs(horizontal) > abs(vertical) {
                                if horizontal > 0 {
                                    scene.handleInput(direction: .right)
                                } else {
                                    scene.handleInput(direction: .left)
                                }
                            } else {
                                if vertical > 0 {
                                    scene.handleInput(direction: .down)
                                } else {
                                    scene.handleInput(direction: .up)
                                }
                            }
                        }
                )
                .onTapGesture { location in
                    scene.handleInputTap(at: location)
                }
        }
    }
}

#Preview {
    ContentView()
}
