import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter reads the Android plugin configuration.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

android {
    namespace = "dev.so1ve.bitree"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    defaultConfig {
        applicationId = "dev.so1ve.bitree"
        manifestPlaceholders["appLabel"] = "BITree"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingPropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = releaseSigning ?: signingConfigs.getByName("debug")

            if (releaseSigning == null) {
                applicationIdSuffix = ".preview"
                manifestPlaceholders["appLabel"] = "BITree 测试版"
            }
        }
    }
}

androidComponents {
    onVariants { variant ->
        val variantName = variant.name.replaceFirstChar { it.uppercaseChar() }
        // Host tests package Flutter assets, so their producer must run first.
        tasks.matching { it.name == "package${variantName}UnitTestForUnitTest" }
            .configureEach { dependsOn("copyFlutterAssets$variantName") }
    }

    onVariants(selector().withBuildType("release")) { variant ->
        // Compress direct-download APKs; keep Play-generated APKs mmap-friendly.
        variant.packaging.jniLibs.useLegacyPackaging.set(true)
        variant.packaging.jniLibs.useLegacyPackagingFromBundle.set(false)
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
    implementation("androidx.core:core-remoteviews:1.1.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}
