#if canImport(UIKit)
    import UIKit
    import SwiftUI
    import ImageIO

    struct GifImageView: UIViewRepresentable {
        let gifName: String

        func makeUIView(context: Context) -> UIImageView {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true

            if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif"),
                let gifData = try? Data(contentsOf: gifURL),
                let source = CGImageSourceCreateWithData(gifData as CFData, nil)
            {

                var images: [UIImage] = []
                var duration: Double = 0

                let count = CGImageSourceGetCount(source)
                for i in 0..<count {
                    if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                        let image = UIImage(cgImage: cgImage)
                        images.append(image)

                        // Get frame duration
                        if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                            as? [String: Any],
                            let gifInfo = properties[kCGImagePropertyGIFDictionary as String]
                                as? [String: Any],
                            let frameDuration = gifInfo[kCGImagePropertyGIFDelayTime as String]
                                as? Double
                        {
                            duration += frameDuration
                        } else {
                            duration += 0.1  // Default duration
                        }
                    }
                }

                imageView.animationImages = images
                imageView.animationDuration = duration
                imageView.animationRepeatCount = 0  // Infinite loop
                imageView.startAnimating()
            }

            return imageView
        }

        func updateUIView(_ uiView: UIImageView, context: Context) {
            // No updates needed
        }
    }
#endif
