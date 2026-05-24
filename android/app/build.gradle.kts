import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from key.properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val mnnArm64Only = providers
    .gradleProperty("mnn.arm64Only")
    .map(String::toBoolean)
    .orElse(true)
    .get()
val flutterTargetPlatforms = providers
    .gradleProperty("target-platform")
    .orElse("android-arm64")
    .get()
    .split(",")
    .map { it.trim() }
    .filter { it.isNotEmpty() }
val arm64OnlyFlutterTarget = flutterTargetPlatforms == listOf("android-arm64")

if (mnnArm64Only && !flutterTargetPlatforms.contains("android-arm64")) {
    val mnnFlutterRunWarning = """
        |========== ReceiptTamer MNN LLM Run Warning ==========
        |ReceiptTamer local LLM requires an arm64 Flutter engine.
        |Current target-platform=${flutterTargetPlatforms.joinToString(",")}.
        |
        |Ordinary flutter run on an x86_64 AVD may pass android-x64.
        |That can start the app, but the arm64-only MNN LLM runtime will be skipped in an x86_64 process.
        |
        |If you want to use MNN LLM on an x86_64 AVD with ARM64 translation:
        |  1. flutter build apk --debug --target-platform android-arm64
        |  2. adb install -r build/app/outputs/flutter-apk/app-debug.apk
        |  3. adb shell am start -n com.acautomaton.receipt.tamer/.MainActivity
        |  4. Optional: flutter attach
        |
        |flutter run does not support --target-platform; build/install/attach instead.
        |=====================================================
    """.trimMargin()
    System.err.println(mnnFlutterRunWarning)
}

android {
    namespace = "com.acautomaton.receipt.tamer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.acautomaton.receipt.tamer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (arm64OnlyFlutterTarget) {
            // NDK配置 - 只支持arm64-v8a (避免armeabi-v7a的FP16指令兼容问题)
            ndk {
                abiFilters += listOf("arm64-v8a")
            }
        }

        // 外部native构建配置
        externalNativeBuild {
            cmake {
                // 只为arm64-v8a构建
                abiFilters += listOf("arm64-v8a")
            }
        }
    }

    // MNN LLM NDK编译配置
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.18.1"
        }
    }

    // 不压缩模型文件，允许通过fd直接访问
    aaptOptions {
        noCompress += listOf("mnn", "json", "txt", "weight")
    }

    if (mnnArm64Only && arm64OnlyFlutterTarget) {
        // MNN LLM runtime is arm64-only. If x86_64 libraries remain in an
        // arm64-target APK, Android may start a translated AVD process as x86_64
        // and fail to load the arm64 MNN libraries.
        packaging {
            jniLibs {
                excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**")
            }
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Paddle-Lite OCR - 使用本地AAR文件 (RapidOcrAndroidOnnx 1.3.0)
    // 从GitHub Release下载: https://github.com/RapidAI/RapidOcrAndroidOnnx/releases
    implementation(files("libs/OcrLibrary-1.3.0-release.aar"))

    // 图片处理
    implementation("androidx.exifinterface:exifinterface:1.3.6")
}

flutter {
    source = "../.."
}
