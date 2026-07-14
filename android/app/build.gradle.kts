import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties()
val localPropsFile = rootProject.file("local.properties")
if (localPropsFile.exists()) {
    localProps.load(FileInputStream(localPropsFile))
}

android {
    namespace = "com.example.my_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.1"
//        versionCode = flutter.versionCode
//        versionName = flutter.versionName

        buildConfigField("String", "MATM_SECRET_KEY",   "\"${localProps["MATM_SECRET_KEY"] ?: ""}\"")
        buildConfigField("String", "MATM_SALT_KEY",     "\"${localProps["MATM_SALT_KEY"] ?: ""}\"")
        buildConfigField("String", "MATM_ENCRYPT_KEY",  "\"${localProps["MATM_ENCRYPT_KEY"] ?: ""}\"")
        buildConfigField("String", "MATM_USER_ID",      "\"${localProps["MATM_USER_ID"] ?: ""}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(files("libs/matm-release.aar"))
    implementation(files("libs/microatm-release_V5.0.aar"))
    implementation(files("libs/morefun_mpos_sdk_v3.0.20240827.jar"))
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.11.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.11.0")
    implementation("androidx.activity:activity-ktx:1.7.0")
    implementation("androidx.core:core:1.12.0")
    implementation("com.google.dagger:hilt-android:2.53.1")

}