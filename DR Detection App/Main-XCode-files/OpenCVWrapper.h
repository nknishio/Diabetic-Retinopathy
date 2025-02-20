#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

+ (UIImage *)applyGraham:(UIImage *)image sigmaX:(int)sigmaX;
+ (UIImage *)applyCLAHE:(UIImage *)image clipLimit:(double)clipLimit tileGridSize:(int)tileGridSize;
//+ (cv::Mat *)cvMat:(UIImage *)image;

@end
