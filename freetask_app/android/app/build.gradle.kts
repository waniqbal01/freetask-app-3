plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.freetask.apps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Load keystore properties from key.properties file
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    var hasValidKeystore = false
    
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        
        // Check if all required properties are present and non-null
        val keyAliasValue = keystoreProperties["keyAlias"] as? String
        val keyPasswordValue = keystoreProperties["keyPassword"] as? String
        val storeFileValue = keystoreProperties["storeFile"] as? String
        val storePasswordValue = keystoreProperties["storePassword"] as? String
        
        hasValidKeystore = keyAliasValue != null && keyPasswordValue != null && 
                          storeFileValue != null && storePasswordValue != null
    }

    defaultConfig {
        // Production Application ID - matches Firebase
        applicationId = "com.freetask.apps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasValidKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use production signing if key.properties is valid, otherwise use debug
            signingConfig = if (hasValidKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug keys for development
                println("⚠️ WARNING: Using debug keys for release build. Run create_keystore.ps1 to setup production signing.")
                signingConfigs.getByName("debug")
            }
        }
    }
}


dependencies {
    constraints {
        // Force byte-buddy to use a version compatible with Java 17
        // Version 1.17.6 was compiled with Java 24 (class file major version 68)
        implementation("net.bytebuddy:byte-buddy:1.14.18") {
            because("Version 1.17.6 requires Java 24, but we're using Java 17")
        }
        implementation("net.bytebuddy:byte-buddy-agent:1.14.18") {
            because("Version 1.17.6 requires Java 24, but we're using Java 17")
        }
    }
    
    // Firebase dependencies managed by Flutter plugins
    
    // Core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
