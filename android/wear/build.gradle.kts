import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val accountProperties = Properties().apply {
    val local = rootProject.file("wear.local.properties")
    if (local.exists()) local.inputStream().use(::load)
}

fun credential(name: String, environment: String): String =
    accountProperties.getProperty(name) ?: System.getenv(environment) ?: ""

fun quoted(value: String): String = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "com.campura.one.campura_one_student.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.campura.one.campura_one_student"
        minSdk = 30
        targetSdk = 36
        versionCode = 1000001
        versionName = "1.0.0"
        buildConfigField("String", "WATCH_ACCOUNT", quoted(credential("wear.userName", "CAMPURA_WEAR_USER")))
        buildConfigField("String", "WATCH_PASSWORD", quoted(credential("wear.password", "CAMPURA_WEAR_PASSWORD")))
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
    }
    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("debug") }
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.12.00"))
    implementation("androidx.activity:activity-compose:1.12.1")
    implementation("androidx.wear.compose:compose-material3:1.6.2")
    implementation("androidx.wear.compose:compose-foundation:1.6.2")
    implementation("androidx.wear.compose:compose-navigation:1.6.2")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}
