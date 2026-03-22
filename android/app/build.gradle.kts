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

        // NDK配置 - 只支持arm64-v8a (避免armeabi-v7a的FP16指令兼容问题)
        ndk {
            abiFilters += listOf("arm64-v8a")
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
