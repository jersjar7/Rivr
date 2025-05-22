plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.byu_hydroinformatics_lab.rivr" // Update to match Firebase
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Override Flutter's default NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Update this to match your Firebase configuration
        // Check your google-services.json for the correct package_name
        applicationId = "com.byu_hydroinformatics_lab.rivr" // Note: underscores instead of hyphens
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Enable BuildConfig generation
    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        getByName("debug") {
            // Remove applicationIdSuffix to avoid Firebase mismatch
            // applicationIdSuffix = ".dev"
            buildConfigField("String", "ENV", "\"development\"")
            isDebuggable = true
            // Disable shrinking for debug builds
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            buildConfigField("String", "ENV", "\"production\"")
            // Enable both code and resource shrinking for release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}