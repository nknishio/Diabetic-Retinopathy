# Diabetic-Retinopathy Detection and Severity Classification
Paper: [IEEE](https://doi.org/10.1109/FMLDS63805.2024.00074)

Slides: [pdf](https://github.com/kneshio/Diabetic-Retinopathy/blob/main/Diabetic%20Retinopathy%20slides_FMLDS2024.pdf)

DR Detection App Demo: [Github](https://github.com/nknishio/Diabetic-Retinopathy/blob/main/DR%20Detection%20App/DR_App_Demo.md)

This study leveraged the two pretrained ResNet50 and VGG19 models for detecting DR in retinal fundus images from the APTOS 2019 dataset. 

**A.	Dataset** 

This study utilized the publicly accessible APTOS 2019 dataset, shown in Fig. 2. The dataset comprises 3,662 retinal fundus images, each sized 3216×2136 pixels, collected from 193 patients using various cameras in different locations. The distribution of images across the DR stages is as follows: 1805 in the no DR group, 370 in the mild DR group, 999 in the moderate DR group, 193 in the severe DR group, and 295 in the proliferate DR group. The dataset is imbalanced with an uneven distribution among the classes, which can negatively impact classification performance. To mitigate this, data augmentation techniques were applied.

**B.	Proposed Image Processing**

In this study, the combinations of the three image preprocessing techniques were fine-tuned and proposed— Graham method, CLAHE, and ESRGAN to address issues such as blurriness, low contrast, and inhomogeneous illumination present in the APTOS dataset.   

The Graham method was proposed by Ben Graham, the winner of the Kaggle DR grading competition, to help remove image variations due to different lighting conditions or imaging devices. In this work,  the Graham method was implemented with OpenCV functions: 

     cv2.addWeighted(image,4,cv2.GaussianBlur(image,(0,0),sigma),-4 ,128)

The role of sigma in the Gaussian filter is to control the variation around its mean value. First, Gaussian Blur was applied with Gaussian kernel size= (0, 0) and sigma= 10, namely Graham10 in this study. Second, the blurred image was blended with the original image with alpha = 4, beta = −4 and gamma = 128. After applying the Graham10 method, the lighting noise in the original image is removed. However, the DR lesions diminish at the same time. When the sigma is increased to 20, referred to as Graham20 in this study, the vessels, microaneurysms and exudates are more prominently highlighted, making them more visible to the human eye. 

Contrast Limited Adaptive Histogram Equalization (CLAHE) is a contrast enhancement method based on Histogram Equalization (HE). While HE increases image contrast by spreading out the most frequently occurring intensity values in the histogram, it also tends to amplify noise. CLAHE is a variant of HE designed to improve image contrast without excessively amplifying noise. In this study, CLAHE was implemented using the OpenCV function with the tile grid size (8, 8) and the clip limit, 2.0. 

Enhanced Super-Resolution Generative Adversarial Networks (ESRGAN), proposed by X. Wang et al. [16], were trained with synthetic data to enhance details while removing noisy artifacts to restore blurry images and videos in very high resolution. In this study, ESRGAN was selected for denoising and restoring the quality of blurry retina fundus images. The combinations of the above three image processing methods were experimented to compare the effectiveness of preprocessing on DR classification.

The combination of the above three methods are experimented to compare the effectiveness of pre-processing on DR detection and classification. 

**C. Result**

This study explores the role of various image processing methods in DR classification, testing different combinations to achieve the best performance of the deep learning model. For early DR detection, the pre-trained VGG19 model with the proposed CLAHE + ESRGAN method achieved an accuracy of 98.91%. To differentiate retinal lesions across different DR stages, ResNet50 was proven to be more effective than VGG19 in capturing distinctive features. For five-DR-stage classification, ResNet50 with Graham20 + CLAHE achieved the highest accuracy of 86.07%, while ResNet50 with CLAHE + ESRGAN showed the second highest accuracy of 84.15%. The pre-trained ResNet50 model performed approximately 2% more accurately than the pre-trained VGG19 model in capturing the distinctive features of the retinal fundus images.

**D. Key Contributions**

1) Recent popular image processing techniques, CLAHE, Gaussian Blur, and ESRGAN, have been systematically studied. Their combinations, with fine-tuned parameters, are proposed for the first time to reduce image noise, enhance contrast, restore blurriness, and highlight DR lesion features, thereby improving multi-DR stage classification performance.

2) This study integrates pre-trained ResNet50 and VGG19 deep learning frameworks with several proposed image preprocessing methods, achieving performance superior to the state-of-the-art methods in prior research. The established ResNet50 deep learning framework can be integrated with electronic health systems in hospitals and clinics to assist medical professionals in diagnosing DR stages so patients can receive appropriate treatment timely. 

3) The proposed image enhancement methods are suggested for integration into retinal camera applications. Once retinal fundus images are captured, users or ophthalmologists at home, at clinic or remote locations can select between different image enhancement methods in the app to highlight the DR lesions for self-screening or professional DR screening. Graham20 + CLAHE is generally suitable for all DR stages, effectively removing lighting noise and making retinal lesions more visible to the human eye.

**F. Publication**

[2024 IEEE International Conference on Future Machine Learning and Data Science](https://www.fmlds.org/AcceptedPapers.php)
