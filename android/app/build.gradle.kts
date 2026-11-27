import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val resolvedStorePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
    .ifEmpty { System.getenv("YUEWEI_KEYSTORE_PATH")?.trim().orEmpty() }
val resolvedStorePassword = keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
    .ifEmpty { System.getenv("YUEWEI_KEYSTORE_PASSWORD")?.trim().orEmpty() }
val resolvedKeyAlias = keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
    .ifEmpty { System.getenv("YUEWEI_KEY_ALIAS")?.trim().orEmpty() }
val resolvedKeyPassword = keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()
    .ifEmpty { System.getenv("YUEWEI_KEY_PASSWORD")?.trim().orEmpty() }

val resolvedKeystoreFile = if (resolvedStorePath.isNotEmpty()) {
    val rawFile = File(resolvedStorePath)
    when {
        rawFile.isAbsolute -> rawFile
        rootProject.file(resolvedStorePath).exists() -> rootProject.file(resolvedStorePath)
        else -> file(resolvedStorePath)
    }
} else {
    null
}

val hasReleaseSigning = resolvedKeystoreFile != null &&
    resolvedKeystoreFile.exists() &&
    resolvedStorePassword.isNotEmpty() &&
    resolvedKeyAlias.isNotEmpty() &&
    resolvedKeyPassword.isNotEmpty()

android {
    namespace = "com.kline.yuewei_reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kline.yuewei"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = resolvedKeystoreFile
                storePassword = resolvedStorePassword
                keyAlias = resolvedKeyAlias
                keyPassword = resolvedKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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
