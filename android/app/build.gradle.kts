import java.net.URL
import java.io.InputStream
import java.io.OutputStream
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Download Node.js Mobile binaries ─────────────────────────────────────────
val nodeJsMobileVersion = "18.20.4"
val nodeJsMobileUrl =
    "https://github.com/nodejs-mobile/nodejs-mobile/releases/download/" +
    "v$nodeJsMobileVersion/nodejs-mobile-v$nodeJsMobileVersion-android.zip"

tasks.register("downloadNodeJsMobile") {
    val soDir   = File(projectDir, "src/main/jniLibs")
    val hdrsDir = File(projectDir, "src/main/cpp/node_include")
    val arm64So = soDir.resolve("arm64-v8a/libnode.so")

    doLast {
        if (arm64So.exists()) {
            println("Node.js Mobile binaries already present — skipping download.")
            return@doLast
        }
        println("Downloading Node.js Mobile v$nodeJsMobileVersion for Android…")
        val zipFile = File(buildDir, "nodejs-mobile-android.zip")
        zipFile.parentFile.mkdirs()
        if (!zipFile.exists()) {
            URL(nodeJsMobileUrl).openStream().use { src: InputStream ->
                zipFile.outputStream().use { dst: OutputStream -> src.copyTo(dst) }
            }
        }
        println("Extracting binaries and headers…")
        ZipInputStream(zipFile.inputStream()).use { zis: ZipInputStream ->
            var entry = zis.nextEntry
            while (entry != null) {
                val dest: File? = when {
                    entry.name == "bin/arm64-v8a/libnode.so" ->
                        soDir.resolve("arm64-v8a/libnode.so")
                    entry.name == "bin/armeabi-v7a/libnode.so" ->
                        soDir.resolve("armeabi-v7a/libnode.so")
                    entry.name == "bin/x86_64/libnode.so" ->
                        soDir.resolve("x86_64/libnode.so")
                    entry.name.startsWith("include/node/") && !entry.isDirectory ->
                        hdrsDir.resolve(entry.name.removePrefix("include/"))
                    else -> null
                }
                if (dest != null) {
                    dest.parentFile.mkdirs()
                    dest.outputStream().use { out -> zis.copyTo(out) }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        println("Node.js Mobile ready!")
    }
}

tasks.whenTaskAdded {
    if (name.startsWith("externalNativeBuild") ||
        name.startsWith("configureCMake") ||
        name == "preBuild") {
        dependsOn("downloadNodeJsMobile")
    }
}

// ── Android config ────────────────────────────────────────────────────────────
android {
    namespace  = "com.aivos.wabot.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "25.2.9519653"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    externalNativeBuild {
        cmake {
            path    = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        create("release") {
            val keystoreFile = System.getenv("WABOT_KEYSTORE_PATH")
            if (keystoreFile != null) {
                storeFile     = file(keystoreFile)
                storePassword = System.getenv("WABOT_STORE_PASSWORD") ?: ""
                keyAlias      = System.getenv("WABOT_KEY_ALIAS") ?: "wabot-key"
                keyPassword   = System.getenv("WABOT_KEY_PASSWORD") ?: ""
            } else {
                storeFile     = file(System.getProperty("user.home") + "/.android/debug.keystore")
                storePassword = "android"
                keyAlias      = "androiddebugkey"
                keyPassword   = "android"
            }
        }
    }

    defaultConfig {
        applicationId = "com.aivos.wabot.app"
        minSdk        = 24
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags  += listOf("-fexceptions", "-frtti")
                abiFilters += setOf("arm64-v8a", "armeabi-v7a", "x86_64")
            }
        }
    }

    buildTypes {
        release {
            signingConfig     = signingConfigs.getByName("release")
            isMinifyEnabled   = false
            isShrinkResources = false
        }
    }

    // Keep Node.js bundle uncompressed for runtime access
    aaptOptions {
        noCompress("js", "json")
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}
