import UIKit

extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio.
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            if size.width <= maxDimension { return self }
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            if size.height <= maxDimension { return self }
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Compresses the image and returns a base64 string.
    /// Resizes to 1024px max dimension and uses 0.5 compression quality by default.
    func compressedBase64(maxDimension: CGFloat = 1024, quality: CGFloat = 0.5) -> String? {
        let resizedImage = self.resized(toMaxDimension: maxDimension)
        guard let imageData = resizedImage.jpegData(compressionQuality: quality) else { return nil }
        return imageData.base64EncodedString()
    }
}
