# DR Detection/Classification App Demo (Work in Progress)

The app allows users to customize the image processing done on the retina fundus images, specifically the proposed methods in the [paper](https://ieeexplore.ieee.org/document/10874046).\
## Functions:
- Toggling Contrast Limited Adaptive Histogram Equalization (CLAHE)
- Toggling Graham Gaussian Blur (described in detail in paper)
  - Using SigmaX = 10 or SigmaX = 20
- Uploading photos from library

## Full image processing flow done in background:
1. Original photo
2. Identify smallest rectangle containing entire field of retina image and crop (remove unnecessary black background)
3. Pad image to square
4. Apply CLAHE + Graham10/Graham20 (Optional)
5. Resize image to 280 x 280
6. Center crop image to 224 x 224
7. Convert the UIImage to a pixel buffer
8. Perform normalization
9. Pass into CoreML model for prediction & probabilities

## Video Demo

https://github.com/user-attachments/assets/b02d68fe-3414-490c-a410-6f1cdf983d1f

The app's classifications currently has many inaccuracies and inconsistencies. I am still working on fixing issues to improve the app.

## Possible Limitations
- Implementation gap between Python and Swift: I did my best to replicate my original Python code for preprocessing to Swift, but there may be some differences that alter the properties of the images that makes it compatible with the CoreML model.
- The current model only uses a saved CoreML model trained from using CLAHE + Graham20, and it is likely incompatible with the other combinations.
