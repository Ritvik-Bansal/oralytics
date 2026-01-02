# Oralytics

Oralytics is a low cost oral health scanner that uses 405 nm near-UV light to make dental plaque fluoresce, then analyzes photos inside a Flutter mobile app. The app highlights problem areas and returns a severity score in seconds.

This repository contains the mobile app (Flutter). The app connects to inference services or local model runners depending on your setup.

## What it does

1. Capture or upload an oral photo (taken under near-UV illumination)
2. Run a pipeline of computer vision models
3. Overlay results (masks and highlights) and compute a severity score
4. Save results for tracking over time

## Models in the pipeline

The app is built around four ML tasks:

- Teeth area-of-interest segmentation  
  Isolates teeth from lips, tongue, and background.

- Plaque / biofilm segmentation  
  Detects fluorescent regions associated with plaque and produces a pixel mask.

- Gingivitis detection  
  Estimates inflammation risk from visual cues near the gumline.

- Calculus (tartar) classification  
  Classifies tartar presence and severity based on texture and color patterns.

## Setup

### Prerequisites

- Flutter SDK installed
- Xcode (for iOS) and/or Android Studio (for Android)
- A device or simulator

Check your environment:

```bash
flutter doctor
```

### Install dependencies

```bash
flutter pub get
```

### Run the app

iOS simulator:

```bash
flutter run
```

Specific device:

```bash
flutter devices
flutter run -d <device_id>
```

## How results are displayed

- Teeth and plaque are shown as overlays (segmentation masks)
- Gingivitis and calculus are shown as predictions with confidence and a severity score
- The app can store scan history to show progress over time (depending on your storage setup)

## Notes and limitations

- Results depend heavily on lighting conditions and image quality
- Near-UV capture should follow consistent distance and exposure for best repeatability
- This tool is for research and educational use and is not a medical device

## Contact

If you have questions about the app or setup, feel free to email ritvikbansal08@gmail.com
