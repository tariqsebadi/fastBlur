//
//  ImageProcessor.m
//  SpookCam
//
//  Created by Jack Wu on 2/21/2014.
//
//

#import "ImageProcessor.h"

@interface ImageProcessor ()

@end

@implementation ImageProcessor

+ (instancetype)sharedProcessor {
  static id sharedInstance = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  
  return sharedInstance;
}

#pragma mark - Public
#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Time: %f", -[startTime timeIntervalSinceNow])
- (void)processImage:(UIImage*)inputImage {
  UIImage * outputImage = [self processUsingPixels:inputImage]; // outputs img results after processing using pixels on inpug img
  
  if ([self.delegate respondsToSelector:
       @selector(imageProcessorFinishedProcessingWithImage:)]) {
    [self.delegate imageProcessorFinishedProcessingWithImage:outputImage];
  }
}




#pragma mark - Private

#define Mask8(x) ( (x) & 0xFF )
#define R(x) ( Mask8(x) )
#define G(x) ( Mask8(x >> 8 ) )
#define B(x) ( Mask8(x >> 16) )
#define A(x) ( Mask8(x >> 24) )
#define RGBAMake(r, g, b, a) ( Mask8(r) | Mask8(g) << 8 | Mask8(b) << 16 | Mask8(a) << 24 )


- (void) gaussBlur_4:(UInt8*)input targetChannel:(UInt8*)output width:(NSInteger)w height:(NSInteger)h radius:(NSInteger)r{
    
    NSArray *boxes = [self boxesForGauss:r deviationNboxes:3];
    [self boxBlur_4:input targetChannel:output width:w height:h radius:( [boxes[2] integerValue] -1) /2]; //( [boxes[0] integerValue] -1)  /2];
    //[self boxBlur_4:output targetChannel:input width:w height:h radius:( [boxes[1] integerValue] -1) /2];//( [boxes[1] integerValue] -1)  /2];
    //[self boxBlur_4:input targetChannel:output width:w height:h radius:( [boxes[2] integerValue] -1) /2];//( [boxes[2] integerValue] -1)  /2];

    //[self boxBlur_4:input targetChannel:output width:w height:h radius:( [boxes[7] integerValue] -1) /2]; //( [boxes[0] integerValue] -1)  /2];
//    [self boxBlur_4:output targetChannel:input width:w height:h radius:( [boxes[4] integerValue] -1) /2];//( [boxes[1] integerValue] -1)  /2];
//    [self boxBlur_4:input targetChannel:output width:w height:h radius:( [boxes[5] integerValue] -1) /2];//( [boxes[2] integerValue] -1)  /2];

}

//NSData *CopyImagePixels(CGImageRef inImage) {
//    return (NSData *)CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(inImage)));
//    //getDataprovider - gets dataprovider of img
//    //dataProviderCopyData - Return a copy of the data specified by provider. Returns NULL if complete copy of the data can't be obtained (for example, if the
//    //underlying data is too large to fit in memory)
//    //bridgingRelease - trash collector
//    
//}

//
//NSData *data = CopyImagePixels(img);
//UInt32 *bytes = (UInt32 *)data.bytes;


- (NSArray *) boxesForGauss:(NSInteger)sigma deviationNboxes:(NSInteger)n{ //sigma - standard deviation, n - number of boxes
    
    // let n_float = n as f32
    CGFloat wIdeal = sqrtf((12 * sigma * sigma / n) + 1.0);  // Ideal averaging filter width
    NSInteger wl = floor(wIdeal);
    
    if((wl & 1) == 0) //if(wl % 2 ==0)
        wl--;
    NSInteger wu = wl + 2;
    
    
    
    CGFloat mIdeal = (12.0 * sigma * sigma - n * wl * wl - 4.0 * n * wl - 3.0 * n) / (-4.0 * wl - 4.0);
    CGFloat m = roundf(mIdeal);
        // var sigmaActual = math.sqrt( (m*wl*wl + (n-m)*wu*wu - n)/12 )
    
    
    NSMutableArray *sizes = [NSMutableArray arrayWithCapacity:n];
    
    for (NSInteger i = 0; i < n; i++)
        [sizes addObject:@(i<m?wl:wu)]; //insertObject:@(i<m?wl:wu) atIndex:0];// adds to front of index or back of index?
        //sizes.push(i<m?wl:wu);
    
    return sizes;
    // to access: [sizes[0] integerValue];
}


- (void) boxBlur_4:(UInt8*)inputPixels targetChannel:(UInt8*)outputPixels width:(NSInteger)w height:(NSInteger)h radius:(NSInteger)r{
    
//    for(NSInteger i = 0; i < (w*h); i++)
//        outputPixels[i] = inputPixels[i];
    memcpy(outputPixels, inputPixels, w*h);
    [self boxBlurH_4:outputPixels targetChannel:inputPixels width:w height:h radius:r];
    [self boxBlurT_4:inputPixels targetChannel:outputPixels width:w height:h radius:r];//swap inp outp
}
- (void) boxBlurH_4:(UInt8*)inputPixels targetChannel:(UInt8*)outputPixels width:(NSInteger)w height:(NSInteger)h radius:(NSInteger)r{
    
    CGFloat iarr = 1.0 / (CGFloat)(r+r+1);
    
    for (NSInteger i = 0; i < h; i++) {
        NSInteger ti = i * w;
        NSInteger li = ti;
        NSInteger ri = ti+r;
        SInt32   fv = inputPixels[ti];
        SInt32   lv = inputPixels[ti+w-1];
        CGFloat   val = (r+1)*fv;
        
        for (NSInteger j = 0; j<r; j++){
            val += inputPixels[ti+j];
        }
        
        for (NSInteger j = 0; j<=r; j++){
            val += (SInt32)inputPixels[ri++] - fv;
            outputPixels[ti++] = (UInt32)round(val*iarr);
        }
        
        for (NSInteger j = r+1; j<w-r; j++){
            val += (SInt32)inputPixels[ri++] - (SInt32)inputPixels[li++];
            outputPixels[ti++] = (UInt32)round(val*iarr);
        }
        
        for (NSInteger j = w-r; j<w; j++){
            val += lv - (SInt32)inputPixels[li++];
            outputPixels[ti++] = (UInt32)round(val*iarr);
        }
    }
    
}

- (void)boxBlurT_4:(UInt8*)inputPixels targetChannel:(UInt8*)outputPixels width:(NSUInteger)w height:(NSUInteger)h radius:(NSUInteger)r{
    
    //CGFloat       iarr = 1/ (r+r+1);
    CGFloat         iarr = 1.0 / (CGFloat)(r+r+1);
    
    for(NSInteger   i = 0; i < w; i++){
        NSInteger   ti = i,
                    li = ti,
                    ri = ti+r*w;
        SInt32   fv = inputPixels[ti];
        SInt32   lv = inputPixels[ti + w * (h-1)]; //NSInt32???
        CGFloat  val = (r+1) * fv;
    
        for(NSInteger j = 0; j<r; j++){
            val += inputPixels[ti + j * w];
        }
        
        for(NSInteger j = 0; j<=r; j++){
            val += (SInt32)inputPixels[ri] - fv;
            
            outputPixels[ti] = (UInt32)round(val*iarr);
            ri  += w;
            ti  += w;
        }
        
        for(NSInteger j=r+1; j<h-r; j++){
            val += (SInt32)inputPixels[ri] - (SInt32)inputPixels[li];
            
            outputPixels[ti] = (UInt32)round(val * iarr);
            li  += w;
            ri  += w;
            ti  += w;
        }
        
        for(NSInteger j=h-r; j<h; j++){
            val += lv - (SInt32)inputPixels[li];
            
            outputPixels[ti] = (UInt32)round(val * iarr);
            li  += w;
            ti  += w;
        }
    }
  }



// this is the does it all function that takes an inputImage, takes its pixels apart, retrieves rgba, and sends each rgb channel
// into our blur functions
- (UIImage *)processUsingPixels:(UIImage*)inputImage {
//
//    CGImageRef testingInputImage = [inputImage CGImage];
//    NSData *data = CopyImagePixels(testingInputImage);
    //UInt32 *bytes = (UInt32 *)data.bytes;
    
    
    
    
    //NSData *data = CopyImagePixels(img);
    //UInt32 *bytes = (UInt32 *)data.bytes;
    
    
  // 1. Get the raw pixels of the image
  UInt32 * inputPixels;
    //UInt32 * outputPixels;
    //rgb pixel buffers
    UInt8 * redInputPixels;
    UInt8 * greenInputPixels;
    UInt8 * blueInputPixels;
    
    UInt8 * redOutputPixels;
    UInt8 * greenOutputPixels;
    UInt8 * blueOutputPixels;
  
    // takes inputImage, turns into inputCGImage
  CGImageRef inputCGImage = [inputImage CGImage]; // original img, "inputImage", from fixed
  NSUInteger inputWidth = CGImageGetWidth(inputCGImage);
  NSUInteger inputHeight = CGImageGetHeight(inputCGImage);
  
//    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(inputCGImage);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  
  NSUInteger bytesPerPixel = 4;
  NSUInteger bitsPerComponent = 8;
  NSUInteger inputBytesPerRow = bytesPerPixel * inputWidth;
    
  //init input pixls, buffer1
  inputPixels = (UInt32 *)calloc(inputHeight * inputWidth, sizeof(UInt32));
    //init output pxls, buffer2
    //outputPixels = (UInt32 *)calloc(inputHeight * inputWidth, sizeof(UInt32));
    //init red blue green pixels
    redInputPixels = (UInt8 *)calloc( (inputWidth * inputHeight), sizeof(UInt8));
    greenInputPixels = (UInt8 *)calloc((inputWidth * inputHeight), sizeof(UInt8));
    blueInputPixels = (UInt8 *)calloc((inputWidth * inputHeight), sizeof(UInt8));
    
    redOutputPixels = (UInt8 *)calloc( (inputWidth * inputHeight), sizeof(UInt8));
    greenOutputPixels = (UInt8 *)calloc((inputWidth * inputHeight), sizeof(UInt8));
    blueOutputPixels = (UInt8 *)calloc((inputWidth * inputHeight), sizeof(UInt8));

    
  //after this, input pixels hold image data
  CGContextRef context = CGBitmapContextCreate(inputPixels, inputWidth, inputHeight,
                                               bitsPerComponent, inputBytesPerRow, colorSpace,
                                               kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
  
  CGContextDrawImage(context, CGRectMake(0, 0, inputWidth, inputHeight), inputCGImage);
    
    

  
//    //get a CGimage of ghost
//    UIImage * ghostImage = [UIImage imageNamed:@"ghost"];
//    CGImageRef ghostCGImage = [ghostImage CGImage];
//
//    //math to figure out the 'rect' where you want to put ghosty inside the input img
//    CGFloat ghostImageAspectRatio = ghostImage.size.width / ghostImage.size.height;
//    NSInteger targetGhostWidth = inputWidth * 0.25;
//    CGSize ghostSize = CGSizeMake(targetGhostWidth, targetGhostWidth / ghostImageAspectRatio);
//    CGPoint ghostOrigin = CGPointMake(inputWidth * 0.5, inputHeight * 0.5);
//
//    //get pxl buffer of Ghosty, with scaling
//    NSUInteger ghostBytesPerRow = bytesPerPixel * ghostSize.width;
//    UInt32 * ghostPixles = (UInt32 *)calloc(ghostSize.width * ghostSize.height, sizeof(UInt32));
//
//    CGContextRef ghostContext = CGBitmapContextCreate(ghostPixles, ghostSize.width, ghostSize.height, bitsPerComponent, ghostBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big); // scaled the image down in context
//
//    //draw the image into frame
//    CGContextDrawImage(ghostContext, CGRectMake(0, 0, ghostSize.width, ghostSize.height), ghostCGImage);
//
//    NSUInteger offsetPixelCountForInput = ghostOrigin.y * inputWidth + ghostOrigin.x;
//    for (NSUInteger j = 0; j < ghostSize.height; j++){
//        for (NSUInteger i =0; i < ghostSize.width; i++){
//            UInt32 * inputPixel = inputPixels + j * inputWidth + i + offsetPixelCountForInput;
//            UInt32 inputColor = *inputPixel;
//
//            UInt32 * ghostPixel = ghostPixles + j * (int)ghostSize.width +i;
//            UInt32 ghostColor = *ghostPixel;
//
//            //blend ghost with 50% alpha
//            CGFloat ghostAlpha = 0.5f * (A(ghostColor) / 255.0);
//            UInt32 newR = R(inputColor) * (1 - ghostAlpha) + R(ghostColor) * ghostAlpha;
//            UInt32 newG = G(inputColor) * (1 - ghostAlpha) + G(ghostColor) * ghostAlpha;
//            UInt32 newB = B(inputColor) * (1 - ghostAlpha) + B(ghostColor) * ghostAlpha;
//
//            //clamp, not really useful here
//            newR = MAX(0,MIN(255, newR));
//            newG = MAX(0,MIN(255, newG));
//            newB = MAX(0,MIN(255, newB));
//
//            *inputPixel = RGBAMake(newR, newG, newB, A(inputColor));
//        }
//    }
//
    /*for (NSUInteger j = 0; j < inputHeight; j++) {
        for (NSUInteger i = 0; i < inputWidth; i++) {
            UInt32 * currentPixel = inputPixels + (j * inputWidth) + i;
            UInt32 color = *currentPixel;
            
            // Average of RGB = greyscale
            UInt32 averageColor = (R(color) + G(color) + B(color)) / 3.0;
            
            *currentPixel = RGBAMake(averageColor, averageColor, averageColor, A(color));
        }
    }*/
    
//    //get r g b channels into buffers
    
//    CGImageRef testingInputImage = [inputImage CGImage];
//    NSData *data = CopyImagePixels(testingInputImage);
//    UInt32 *bytes = (UInt32 *)data.bytes;

    NSInteger k = 0;
    for(NSUInteger i = 0; i < inputWidth * inputHeight; i++){
        UInt32 * currentPixel = inputPixels + i;
        UInt32 color = *currentPixel;
        
        redInputPixels[k]   = R(color);
        greenInputPixels[k] = G(color);
        blueInputPixels[k]  = B(color);
        k++;
    }
    
    
    TICK;
    [self gaussBlur_4:redInputPixels targetChannel:redOutputPixels width:inputWidth height:inputHeight radius:10];
    //[self boxBlur_4:redInputPixels targetChannel:redOutputPixels width:inputWidth height:inputHeight radius:21];
    //[self boxBlur_4:redInputPixels targetChannel:redOutputPixels width:inputWidth height:inputHeight radius:21];
    TOCK;
    [self gaussBlur_4:greenInputPixels targetChannel:greenOutputPixels width:inputWidth height:inputHeight radius:10];
    //[self boxBlur_4:greenInputPixels targetChannel:greenOutputPixels width:inputWidth height:inputHeight radius:21];
    //[self boxBlurT_4:greenInputPixels targetChannel:greenOutputPixels width:inputWidth height:inputHeight radius:21];
    TOCK;
    [self gaussBlur_4:blueInputPixels targetChannel:blueOutputPixels width:inputWidth height:inputHeight radius:10];
    //[self boxBlur_4:blueInputPixels targetChannel:blueOutputPixels width:inputWidth height:inputHeight radius:21];
    //[self boxBlurT_4:blueInputPixels targetChannel:blueOutputPixels width:inputWidth height:inputHeight radius:21];
    TOCK;

    
    k=0;
    
    for(NSUInteger i = 0; i < inputWidth * inputHeight; i++){
        UInt32 * currentPixel = inputPixels + i;
        UInt32 color = *currentPixel;
        //*currentPixel = RGBAMake(redInputPixels[k], greenInputPixels[k], blueInputPixels[k], A(color));
        *currentPixel = RGBAMake(redOutputPixels[k], greenOutputPixels[k], blueOutputPixels[k], A(color));
        k++;
    }
    
    
    //create a new uiimage
    CGImageRef newCGImage = CGBitmapContextCreateImage(context);
    UIImage * processedImage = [UIImage imageWithCGImage: newCGImage];
    
    //clean up
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    //CGContextRelease(ghostContext);
    free(inputPixels);
    free(redInputPixels);
    free(greenInputPixels);
    free(blueInputPixels);
    free(redOutputPixels);
    free(greenOutputPixels);
    free(blueOutputPixels);
    //free(ghostPixles);
    
  //return inputImage; // replaced
    return processedImage;
}


@end
