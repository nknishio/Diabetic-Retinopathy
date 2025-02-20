//
//  OpenCVWrapper.m
//  Diabetic Retinopathy Detection
//
//  Created by Nelson on 11/25/24.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/core.hpp>
#import "OpenCVWrapper.h"
#import <UIKit/UIKit.h>

using namespace cv;
cv::Mat UIImageToMat(UIImage *image) {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = CGImageGetWidth(image.CGImage);
    CGFloat rows = CGImageGetHeight(image.CGImage);
    
    cv::Mat mat(rows, cols, CV_8UC4); // CV_8UC4 means 8-bit, 4-channel (RGBA)
    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    cv::Mat matBGR;
    cvtColor(mat, matBGR, cv::COLOR_RGBA2BGR); // Convert RGBA to BGR
    return matBGR;
}

// Convert cv::Mat to UIImage
UIImage *MatToUIImage(const cv::Mat &mat) {
    cv::Mat matRGBA;
    cvtColor(mat, matRGBA, cv::COLOR_BGR2RGBA); // Convert BGR to RGBA
    
    NSData *data = [NSData dataWithBytes:matRGBA.data length:matRGBA.elemSize() * matRGBA.total()];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matRGBA.cols,
                                        matRGBA.rows,
                                        8,
                                        32,
                                        matRGBA.step[0],
                                        colorSpace,
                                        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault);
    
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}
cv::Mat cropImageFromGray(const cv::Mat& img, int tol = 7) {
    // Check if the image is grayscale
    if (img.channels() == 1) {
        // Create a mask for pixels greater than the tolerance
        cv::Mat mask = img > tol;
        
        // If no pixels satisfy the condition, return the original image
        if (cv::countNonZero(mask) == 0)
            return img;

        // Find the bounding rectangle of the non-zero region
        cv::Rect boundingBox = cv::boundingRect(mask);

        // Crop the image using the bounding box
        return img(boundingBox);
    }
    // If the image is in color (3 channels)
    else if (img.channels() == 3) {
        // Convert to grayscale
        cv::Mat grayImg;
        cv::cvtColor(img, grayImg, COLOR_BGR2GRAY);

        // Create a mask for pixels greater than the tolerance
        cv::Mat mask = grayImg > tol;

        // If no pixels satisfy the condition, return the original image
        if (cv::countNonZero(mask) == 0)
            return img;

        // Find the bounding rectangle of the non-zero region
        cv::Rect boundingBox = boundingRect(mask);

        // Crop each channel separately
        std::vector<cv::Mat> channels;
        cv::split(img, channels);
        
        cv::Mat croppedChannel1 = channels[0](boundingBox);
        cv::Mat croppedChannel2 = channels[1](boundingBox);
        cv::Mat croppedChannel3 = channels[2](boundingBox);

        // Merge the cropped channels back into a single image
        cv::Mat croppedImage;
        std::vector<cv::Mat> croppedChannels = {croppedChannel1, croppedChannel2, croppedChannel3};
        cv::merge(croppedChannels, croppedImage);

        return croppedImage;
    }

    // If the input image does not have 1 or 3 channels, return the original image
    return img;
}

@implementation OpenCVWrapper

+ (UIImage *)applyGraham:(UIImage *)image sigmaX:(int)sigmaX {
    cv::Mat matImage = UIImageToMat(image);
    cv::Mat croppedImage = cropImageFromGray(matImage);
    cv::Mat rgbImage;
    cvtColor(croppedImage, rgbImage, COLOR_BGR2RGB);
    
    // Apply Gaussian blur
    cv::Mat blurredImage;
    GaussianBlur(rgbImage, blurredImage, cv::Size(0, 0), sigmaX);
    // Perform weighted blending
    cv::Mat processedImage;
    addWeighted(rgbImage, 4.0, blurredImage, -4.0, 128, processedImage);
    
    // Convert the processed image back to BGR
    cv::Mat finalImage;
    cvtColor(processedImage, finalImage, COLOR_RGB2BGR);
    
    UIImage *finalUIImage = MatToUIImage(finalImage);
    return finalUIImage;
}

+ (UIImage *)applyCLAHE:(UIImage *)image clipLimit:(double)clipLimit tileGridSize:(int)tileGridSize {
    cv::Mat matImage = UIImageToMat(image);
    cv::Mat croppedImage = cropImageFromGray(matImage, 7);

    // Step 2: Convert the cropped image to LAB color space
    cv::Mat labImage;
    cv::cvtColor(croppedImage, labImage, COLOR_BGR2Lab);

    // Step 3: Split the LAB image into channels
    std::vector<cv::Mat> labChannels(3);
    cv::split(labImage, labChannels); // LAB channels: L (lightness), A, B

    // Step 4: Apply CLAHE on the L channel
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(clipLimit, cv::Size(tileGridSize, tileGridSize));
    cv::Mat clChannel; // CLAHE-enhanced L channel
    clahe->apply(labChannels[0], clChannel);

    // Step 5: Merge the CLAHE-enhanced L channel with the A and B channels
    labChannels[0] = clChannel;
    cv::Mat enhancedLabImage;
    cv::merge(labChannels, enhancedLabImage);

    // Step 6: Convert the LAB image back to BGR color space
    cv::Mat enhancedImage;
    cvtColor(enhancedLabImage, enhancedImage, COLOR_Lab2BGR);
    
    UIImage *enhancedUIImage = MatToUIImage(enhancedImage);
    // Step 7: Return the enhanced image
    return enhancedUIImage;
}

@end
