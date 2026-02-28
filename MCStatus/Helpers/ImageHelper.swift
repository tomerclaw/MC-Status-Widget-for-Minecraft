//
//  ImageHelper.swift
//  MCStatusDataLayer
//
//  Created by Tomer Shemesh on 10/10/24.
//

import Foundation
import UIKit
import CoreGraphics

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
    
    /// Downscales a UIImage to fit within targetSize, maintaining aspect ratio.
    /// Uses Core Graphics so it works on both iOS and watchOS.
    /// Returns the original image if it's already smaller than targetSize.
    static func resized(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let currentWidth = image.size.width * image.scale
        let currentHeight = image.size.height * image.scale
        guard currentWidth > targetSize.width || currentHeight > targetSize.height else {
            return image  // already small enough
        }
        
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let sourceSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scaleRatio = min(widthRatio, heightRatio)
        let destinationSize = CGSize(
            width: max(1, floor(sourceSize.width * scaleRatio)),
            height: max(1, floor(sourceSize.height * scaleRatio))
        )
        
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(destinationSize.width),
            height: Int(destinationSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: destinationSize))
        
        guard let resizedCGImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: resizedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Processes a user-picked UIImage into Data ready to store in `customIconData`.
    /// - Center-crops to square
    /// - Downscales to at most 512×512 pixels
    /// - Always encodes as PNG at scale 1.0 (no retina inflation)
    /// Uses UIGraphicsImageRenderer to handle CIImage-backed UIImages (e.g. HEIC from PhotosPicker)
    /// that have a nil cgImage property, which would silently fail with a cgImage crop approach.
#if !os(watchOS)
    static func processCustomIcon(_ image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let side = min(pixelWidth, pixelHeight)
        let targetSide = min(side, 512)
        let targetSize = CGSize(width: targetSide, height: targetSide)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        let result = renderer.image { _ in
            // Center-crop: compute source rect in points
            let srcSide = min(image.size.width, image.size.height)
            let srcX = (image.size.width - srcSide) / 2
            let srcY = (image.size.height - srcSide) / 2
            let scale = targetSide / (srcSide * image.scale)  // points→target scale
            image.draw(in: CGRect(
                x: -srcX * scale * image.scale,
                y: -srcY * scale * image.scale,
                width: image.size.width * scale * image.scale,
                height: image.size.height * scale * image.scale
            ))
        }
        return result.pngData()
    }
    #endif
}

