import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

// Release builds are signed with the standard Android debug keystore instead
// of a committed private key. This keeps a real signing key out of a public
// git repo, while still producing an installable, consistently-signed APK
// both locally and on GitHub Actions (the keystore is auto-generated here if
// it doesn't already exist, so updates keep the same signature across runs).
val debugKeystoreDir = File(System.getProperty("user.home"), ".android")
val debugKeystoreFile = File(debugKeystoreDir, "debug.keystore")
if (!debugKeystoreFile.exists()) {
    debugKeystoreDir.mkdirs()
    exec {
        commandLine(
            "keytool", "-genkeypair", "-v",
            "-keystore", debugKeystoreFile.absolutePath,
            "-storepass", "android",
            "-alias", "androiddebugkey",
            "-keypass", "android",
            "-keyalg", "RSA", "-keysize", "2048",
            "-validity", "10000",
            "-dname", "CN=Android Debug,O=Android,C=US",
        )
    }
}

android {
    namespace = "com.musify.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        applicationId = "com.musify.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "flavor"

    productFlavors {
        create("github") {
            dimension = "flavor"
            applicationIdSuffix = ""
        }
        create("fdroid") {
            dimension = "flavor"
            applicationIdSuffix = ".fdroid"
        }
    }

    signingConfigs {
        create("release") {
            storeFile = debugKeystoreFile
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildFeatures {
        buildConfig = true
    }

    dependenciesInfo {
        // Disables dependency metadata when building APKs.
        includeInApk = false
        // Disables dependency metadata when building Android App Bundles.
        includeInBundle = false
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = " DEBUG"
        }
    }
}

flutter {
    source = "../.."
}

afterEvaluate {
    apply(from = "../no-build-id.gradle")
}
