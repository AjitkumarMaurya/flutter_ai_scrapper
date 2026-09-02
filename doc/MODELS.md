# On-Device Model Selection & Architecture Guide

`flutter_ai_scrapper` supports true on-device LLM inference via Google's `flutter_gemma` plugin. Models run locally on hardware accelerators (NPU/GPU/CPU) without network calls or per-token API bills.

---

## 1. Supported Model Catalogue

| Model | Size | Family | Engine File | Tools Support | Best Used For |
|---|---|---|---|---|---|
| **Gemma 3 1B** *(Default)* | ~550 MB | `gemmaIt` | `.litertlm` | Yes | General-purpose on-device schema extraction on modern phones |
| **FunctionGemma 270M** | ~300 MB | `functionGemma` | `.litertlm` | Yes | Resource-constrained devices needing strict tool-call extraction |
| **Qwen 0.6B** | ~400 MB | `qwen3` | `.litertlm` | Yes | Low-RAM devices and multilingual extraction |
| **Gemma 4 E2B** | ~2.4 GB | `gemma4` | `.litertlm` | Yes | High-precision extraction and complex document synthesis |
| *Gemma 3 270M (Excluded)* | ~200 MB | `gemmaIt` | `.litertlm` | **No** | **Excluded:** lacks tool/function tokens required for schema extraction |

---

## 2. Hardware & Storage Requirements

- **RAM Requirements:**
  - 1B models require ~1.2 GB of free system memory during active inference.
  - 270M models require ~600 MB of free system memory.
- **Storage Footprint:**
  - Models are downloaded once to the application's secure support directory and persist between app launches.
  - `ModelManager.getStorageInfo()` reports current disk consumption and available device storage.

---

## 3. Inference Engine Selection

In your Flutter app initialization (`main.dart`), register the appropriate engine:

```dart
await FlutterGemma.initialize(
  inferenceEngines: [
    LiteRtLmEngine(),    // Optimized LiteRT for modern ARM64 devices
    MediaPipeEngine(),   // Fallback for x86_64 emulators and older 32-bit devices
  ],
);
```

---

## 4. Hugging Face Gated Repository Setup

Google's Gemma models are distributed as gated repositories on Hugging Face:

1. Create a Hugging Face account at [huggingface.co](https://huggingface.co).
2. Visit the repository page (e.g. `google/gemma-3-1b-it`) and accept the license terms.
3. Generate a read access token under **Settings > Access Tokens**.
4. Pass the token when installing models:
   ```dart
   final manager = ModelManager();
   await manager.install(
     GemmaModels.gemma31b,
     token: 'hf_YOUR_READ_TOKEN',
     onProgress: (p) => print('Download: ${(p * 100).toInt()}%'),
   );
   ```
