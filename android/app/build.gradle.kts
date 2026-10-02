import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.heiphaistos.nitroid"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.heiphaistos.nitroid"
        // Android 8.0+ : toutes les API de diagnostic utilisées sont disponibles.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signature de release : clé privée via android/key.properties (local) ou secrets
    // de la CI si fournis. Sinon, repli sur la clé PARTAGÉE commitée dans le dépôt
    // (keystore/nitroid-shared.jks, mot de passe public) : ainsi tous les builds
    // signent avec la même clé et les mises à jour s'installent par-dessus sans
    // désinstaller. À remplacer par une vraie clé pour une distribution sérieuse.
    val keyProps = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    fun secret(name: String, env: String): String? = keyProps.getProperty(name) ?: System.getenv(env)
    val storePath = secret("storeFile", "NITROID_KEYSTORE")
    val sharedKey = rootProject.file("../keystore/nitroid-shared.jks")
    // true dès qu'une clé stable est disponible (secret CI/local OU clé partagée commitée).
    val hasStableKey = (storePath != null && file(storePath).exists()) || sharedKey.exists()

    signingConfigs {
        if (hasStableKey) {
            create("release") {
                if (storePath != null && file(storePath).exists()) {
                    storeFile = file(storePath)
                    storePassword = secret("storePassword", "NITROID_KEYSTORE_PASSWORD")
                    keyAlias = secret("keyAlias", "NITROID_KEY_ALIAS")
                    keyPassword = secret("keyPassword", "NITROID_KEY_PASSWORD")
                } else {
                    storeFile = sharedKey
                    storePassword = "nitroid-shared"
                    keyAlias = "nitroid"
                    keyPassword = "nitroid-shared"
                }
            }
        }
    }

    buildTypes {
        release {
            // Clé stable si disponible, sinon clé debug (build toujours possible).
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    lint {
        // Les permissions protégées sont volontaires (accordées via ADB).
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider pour la mise à jour intégrée.
    implementation("androidx.core:core-ktx:1.13.1")
}
