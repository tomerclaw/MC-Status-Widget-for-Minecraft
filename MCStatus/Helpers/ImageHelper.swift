//
//  ImageHelper.swift
//  MCStatusDataLayer
//
//  Created by Tomer Shemesh on 10/10/24.
//

import Foundation
import UIKit

class ImageHelper {
    static func convertFavIconString(favIcon: String?) -> UIImage? {
        if let favIconString = favIcon, favIconString != "" {
            let favIconParts = favIconString.split(separator: ",")
            guard favIconParts.count == 2 else {
                return nil
            }
            if let decodedData = Data(base64Encoded: String(favIconParts[1]), options: .ignoreUnknownCharacters) {
                return UIImage(data: decodedData)
            }
        }
        return nil
    }

    /// Processes a user-picked UIImage into Data ready to store in `customIconData`.
    /// - Center-crops to square
    /// - If pixel width > 512: downscales to 512×512
    /// - Always encodes as PNG
    #if !os(watchOS)
    static func processCustomIcon(_ image: UIImage) -> Data? {
        let cropped = image.squareCropped()
        let pixelWidth = cropped.size.width * cropped.scale
        if pixelWidth > 512 {
            return cropped.resized(to: CGSize(width: 512, height: 512)).pngData()
        } else {
            return cropped.pngData()
        }
    }
    #endif
}

private extension UIImage {
    func squareCropped() -> UIImage {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let cropRect = CGRect(
            x: origin.x * scale, y: origin.y * scale,
            width: side * scale, height: side * scale
        )
        guard let cgCropped = cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgCropped, scale: scale, orientation: imageOrientation)
    }

    #if !os(watchOS)
    func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: targetSize)) }
    }
    #endif
}





