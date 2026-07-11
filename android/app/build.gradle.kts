plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.big_text"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.big_text"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Rename APK output to the project name (e.g., big_text.apk)
afterEvaluate {
    android.applicationVariants.all { variant ->
        variant.outputs.all { output ->
            try {
                val apkName = "${rootProject.name}.apk"
                // Some Gradle versions expose 'outputFileName' directly
                output::class.java.getMethod("setOutputFileName", String::class.java)
                    .invoke(output, apkName)
            } catch (e: NoSuchMethodException) {
                try {
                    val field = output::class.java.getDeclaredField("outputFile")
                    field.isAccessible = true
                    field.set(output, file("${rootProject.name}.apk"))
                } catch (_: Throwable) {
                    // best-effort: if we can't set the name, ignore silently
                }
            } catch (_: Throwable) {
                // ignore other reflection errors
            }
        }
    }
}
