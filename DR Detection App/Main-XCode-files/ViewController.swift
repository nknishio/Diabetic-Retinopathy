import UIKit
import CoreML
import CoreGraphics
import CoreImage
import Accelerate

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var originalImageView: UIImageView!
    @IBOutlet weak var croppedImageView: UIImageView!
    @IBOutlet weak var squaredImageView: UIImageView!
    @IBOutlet weak var processedImageView: UIImageView!
    @IBOutlet weak var resizedImageView: UIImageView!
    
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var grahamSwitch: UISwitch!
    @IBOutlet weak var claheSwitch: UISwitch!
    @IBOutlet weak var uploadButton: UIButton!
    
    var isGrahamEnabled: Bool = true
    var isClaheEnabled: Bool = true
    
    @IBAction func grahamSwitchToggled(_ sender: UISwitch) {
        // Logic for toggling Graham processing
        isGrahamEnabled = sender.isOn
    }
    
    @IBAction func claheSwitchToggled(_ sender: UISwitch) {
        // Logic for toggling CLAHE processing
        isClaheEnabled = sender.isOn
    }
    var model: ClaheBen20_Resnet50?
    let classLabels = ["Healthy", "Mild DR", "Moderate DR", "Severe DR", "Proliferative DR"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpImageViewBorders()
        do {
            model = try ClaheBen20_Resnet50(configuration: .init()) // Try initializing the model
        } catch {
            print("Error: Model initialization failed.")
            predictionLabel.text = "Error: Model initialization failed."
        }
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Sigma 10", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Sigma 20", at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = 0 // Default selection
    }
    var selectedSigmaX: Int32 = 10 // Default value
    @IBAction func sigmaValueChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            selectedSigmaX = 10
        } else {
            selectedSigmaX = 20
        }
    }
    
    // MARK: Uploading photo
    @IBAction func uploadPhotoButtonTapped(_ sender: UIButton) {
        openPhotoLibrary()
    }
    
    func openPhotoLibrary() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        DispatchQueue.main.async {
            self.present(imagePicker, animated: true, completion: nil)
        }
        print("Successfully opened library.")
        
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            originalImageView.image = selectedImage
            processImage(image: selectedImage)
        } else {
            print("No image selected.")
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: Processing Functions
    
    func padToSquare(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        
        let width = cgImage.width
        let height = cgImage.height
        let squareSize = max(width, height)
        
        let newSize = CGSize(width: squareSize, height: squareSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        
        let padX = (squareSize - width) / 2
        let padY = (squareSize - height) / 2
        
        image.draw(in: CGRect(x: padX, y: padY, width: width, height: height))
        
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return paddedImage
    }
    
    func applyResize(image: UIImage, newSize: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = Int(newSize.width)
        let height = Int(newSize.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: cgImage.bitsPerComponent,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else { return nil }
        
        context.interpolationQuality = .default  // Equivalent to OpenCV’s INTER_LINEAR
        
        // Draw the resized image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get the resized image
        guard let resizedCGImage = context.makeImage() else { return nil }
        
        return UIImage(cgImage: resizedCGImage)
    }
    
    func centerCrop(image: UIImage, targetSize: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else {
            print("Error: Unable to get CGImage from UIImage.")
            return nil
        }
        
        let originalSize = image.size
        guard originalSize.width >= targetSize.width, originalSize.height >= targetSize.height else {
            print("Error: Target crop size is larger than the original image size.")
            return nil
        }

        let xOffset = (originalSize.width - targetSize.width) / 2
        let yOffset = (originalSize.height - targetSize.height) / 2
        let cropRect = CGRect(x: xOffset * image.scale, y: yOffset * image.scale,
                              width: targetSize.width * image.scale, height: targetSize.height * image.scale)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            print("Error: Cropping failed.")
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func cropImageFromGray(_ img: UIImage, tol: UInt8 = 7) -> UIImage {
        guard let cgImage = img.cgImage else { return img }
        let width = cgImage.width
        let height = cgImage.height
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return img }
        
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        
        var minX = width, minY = height, maxX = 0, maxY = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = data[pixelIndex]
                let g = data[pixelIndex + 1]
                let b = data[pixelIndex + 2]
                
                let grayValue = (0.299 * Float(r)) + (0.587 * Float(g)) + (0.114 * Float(b))
                
                if grayValue > Float(tol) {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        
        if minX >= maxX || minY >= maxY {
            return img // Return original image if completely dark
        }
        
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage)
        }
        
        return img
    }


    // MARK: Processing + Prediction
    
    func softmax(_ logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0
        let expLogits = logits.map { exp($0 - maxLogit) }  // Subtract maxLogit for numerical stability
        let sumExpLogits = expLogits.reduce(0, +)
        return expLogits.map { $0 / sumExpLogits }
    }
    
    func makePrediction(image: UIImage) {
        guard let pixelBuffer = image.toCVPixelBuffer() else {
            print("Error: Could not convert image to CVPixelBuffer")
            predictionLabel.text = "Error preparing image for prediction."
            return
        }
        
        let imgMean: [Float] = [0.4925, 0.4914, 0.4886]
        let imgStd: [Float] = [0.1610, 0.1615, 0.1243]
        
        
        guard let normalizedMLArray = normalizeImage(pixelBuffer: pixelBuffer, mean: imgMean, std: imgStd) else {
                print("Error: Could not normalize")
                predictionLabel.text = "Error preparing image for prediction."
                return
            }
            
        // Convert back to CVPixelBuffer for model input
        guard let normalizedPixelBuffer = mlMultiArrayToCVPixelBuffer(normalizedMLArray) else {
            print("Error: Could not convert normalized image back to pixel buffer")
            return
        }
        
        do {
            guard let model = model else {
                print("Error: Model could not be loaded")
                return
            }
            
            let prediction = try model.prediction(input: ClaheBen20_Resnet50Input(input: normalizedPixelBuffer))
            
            let logits = prediction.linear_2.toArray(type: Float32.self)
            let probabilities = softmax(logits)
            
            let maxIndex = probabilities.firstIndex(of: probabilities.max() ?? 0) ?? 0
            let predictedClass = classLabels[maxIndex]
            
            predictionLabel.text = "Prediction: \(predictedClass) (\(probabilities[maxIndex] * 100)%)"
            
            print("Raw logits: \(logits)")
            print("Probabilities: \(probabilities)")
            
        } catch {
            print("Error making prediction: \(error)")
            predictionLabel.text = "Error during prediction."
        }
    }

    
    func processImage(image: UIImage) {
        DispatchQueue.main.async {
            self.uploadButton.isEnabled = false
            self.predictionLabel.text = "Processing image..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var processedImage = image
            
            // Step 1: Crop from gray (remove unnecessary background)
            let croppedImage = self.cropImageFromGray(processedImage)
            if croppedImage == processedImage {
                print("Crop from gray made no changes.")
            }
            processedImage = croppedImage
            print("Cropped image size: \(processedImage.size.width) x \(processedImage.size.height)")
            
            // Display cropped image
            DispatchQueue.main.async {
                self.croppedImageView.image = croppedImage
            }
            
            // Step 2: Pad to square
            guard let paddedImage = self.padToSquare(image: processedImage) else {
                print("Pad to square failed.")
                return
            }
            processedImage = paddedImage
            print("Padded image size: \(processedImage.size.width) x \(processedImage.size.height)")
            
            // Display squared image
            DispatchQueue.main.async {
                self.squaredImageView.image = paddedImage
            }
            
            // Step 3: Apply CLAHE
            if self.isClaheEnabled {
                processedImage = OpenCVWrapper.applyCLAHE(processedImage, clipLimit: 2.0, tileGridSize: 8)
            }
            
            // Step 4: Apply Graham Processing
            if self.isGrahamEnabled {
                processedImage = OpenCVWrapper.applyGraham(processedImage, sigmaX: self.selectedSigmaX)
            }
            DispatchQueue.main.async {
                self.processedImageView.image = processedImage
            }
            
            // Step 5: Resize to 280×280
            guard let resizedImage = self.applyResize(image: processedImage, newSize: CGSize(width: 280, height: 280)) else {
                print("Resize failed.")
                return
            }
            processedImage = resizedImage
            print("Resized image size: \(processedImage.size.width) x \(processedImage.size.height)")
            
            // Display resized image
            DispatchQueue.main.async {
                self.resizedImageView.image = resizedImage
            }

            // Step 6: Center Crop to 224×224
            guard let croppedCenterImage = self.centerCrop(image: processedImage, targetSize: CGSize(width: 224, height: 224)) else {
                print("Center cropping failed.")
                return
            }
            processedImage = croppedCenterImage
            print("Final cropped image size: \(processedImage.size.width) x \(processedImage.size.height)")
            
            // Display final processed image
            DispatchQueue.main.async {
                self.imageView.image = croppedCenterImage
                self.makePrediction(image: croppedCenterImage)
                self.uploadButton.isEnabled = true
            }
        }
    }
    func setUpImageViewBorders() {
        let borderColor = UIColor.white.cgColor // White border color
        let borderWidth: CGFloat = 2.0 // Set the thickness of the border

        // Set border for each imageView
        self.imageView.layer.borderColor = borderColor
        self.imageView.layer.borderWidth = borderWidth
        self.imageView.layer.cornerRadius = 8 // Optional: add corner radius for rounded corners
        self.imageView.clipsToBounds = true // Ensures that the content is clipped within the rounded corners

        self.originalImageView.layer.borderColor = borderColor
        self.originalImageView.layer.borderWidth = borderWidth
        self.originalImageView.layer.cornerRadius = 8
        self.originalImageView.clipsToBounds = true

        self.croppedImageView.layer.borderColor = borderColor
        self.croppedImageView.layer.borderWidth = borderWidth
        self.croppedImageView.layer.cornerRadius = 8
        self.croppedImageView.clipsToBounds = true

        self.squaredImageView.layer.borderColor = borderColor
        self.squaredImageView.layer.borderWidth = borderWidth
        self.squaredImageView.layer.cornerRadius = 8
        self.squaredImageView.clipsToBounds = true

        self.processedImageView.layer.borderColor = borderColor
        self.processedImageView.layer.borderWidth = borderWidth
        self.processedImageView.layer.cornerRadius = 8
        self.processedImageView.clipsToBounds = true

        self.resizedImageView.layer.borderColor = borderColor
        self.resizedImageView.layer.borderWidth = borderWidth
        self.resizedImageView.layer.cornerRadius = 8
        self.resizedImageView.clipsToBounds = true
    }

    func normalizeImage(pixelBuffer: CVPixelBuffer, mean: [Float], std: [Float]) -> MLMultiArray? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let channels = 3  // Assuming RGB
        
        let imageByteCount = width * height * channels
        var imageBuffer = [Float](repeating: 0, count: imageByteCount)
        
        // Convert pixel data to float
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for i in 0..<imageByteCount {
            imageBuffer[i] = Float(buffer[i]) / 255.0  // Scale to [0,1]
        }
        
        // Normalize using mean and std
        for c in 0..<channels {
            let meanVal = mean[c]
            let stdVal = std[c]
            for i in stride(from: c, to: imageByteCount, by: channels) {
                imageBuffer[i] = (imageBuffer[i] - meanVal) / stdVal
            }
        }
        
        // Convert to MLMultiArray
        let mlArray = try? MLMultiArray(shape: [1, NSNumber(value: channels), NSNumber(value: height), NSNumber(value: width)], dataType: .float32)
        
        guard let multiArray = mlArray else { return nil }
        
        for i in 0..<imageByteCount {
            multiArray[i] = NSNumber(value: imageBuffer[i])
        }
        
        return multiArray
    }

    func mlMultiArrayToCVPixelBuffer(_ multiArray: MLMultiArray) -> CVPixelBuffer? {
        let width = 224  // Set this to match your model's expected input size
        let height = 224
        let channels = 3  // RGB
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Error creating pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, .init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(buffer)!
        let floatData = multiArray.dataPointer.bindMemory(to: Float.self, capacity: width * height * channels)
        
        // Convert normalized Float values back to UInt8 pixel data
        for i in 0..<(width * height * channels) {
            let normalizedPixel = floatData[i]  // This is the normalized value
            let denormalizedPixel = UInt8(min(max((normalizedPixel * 255), 0), 255)) // Convert back to 0-255
            data.assumingMemoryBound(to: UInt8.self)[i] = denormalizedPixel
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, .init(rawValue: 0))
        
        return buffer
    }
    

}

// Helper extension to convert MLMultiArray to Swift Array
extension MLMultiArray {
    func toArray<T>(type: T.Type) -> [T] {
        let pointer = UnsafeMutablePointer<T>(OpaquePointer(self.dataPointer))
        let buffer = UnsafeBufferPointer(start: pointer, count: self.count)
        return Array(buffer)
    }
}

// Helper extension to convert UIImage to CVPixelBuffer
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else {
            print("Error: Unable to get CGImage from UIImage")
            return nil
        }

        let frameSize = CGSize(width: 224, height: 224) // Resize based on model input dimensions
        var pixelBuffer: CVPixelBuffer?

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(frameSize.width),
            Int(frameSize.height),
            kCVPixelFormatType_32BGRA,  // Corrected pixel format type
            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Error: Unable to create pixel buffer")
            return nil
        }

        // Create a CGContext with the pixel buffer (no alpha channel needed for RGB)
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(frameSize.width),
            height: Int(frameSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),  // Device RGB color space
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        // Draw the image into the context, resizing it to 224x224
        context?.draw(cgImage, in: CGRect(origin: .zero, size: frameSize))

        return pixelBuffer
    }

    

}

