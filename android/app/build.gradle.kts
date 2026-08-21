plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- IMPORTS NECESARIOS ---
import java.io.FileInputStream
import java.util.Properties
// -----------------------------------------

// Carga de key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.martinguemesfutbol.app" // El namespace principal queda igual
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // ¡ATENCIÓN! Sacamos el applicationId de acá porque ahora lo define cada "sabor"
        minSdk = 24
        targetSdk = 36
        versionCode = 78
        versionName = "1.1.0"
        multiDexEnabled = true

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // =========================================================================
    // --- NUEVO BLOQUE: SOLUCIÓN A BLOQUEO DE ARCHIVOS EN WINDOWS (LINT) ---
    // =========================================================================
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
    // =========================================================================

    // ========================================================
    // LA MAGIA MULTIFLAVOR: DEFINIMOS LOS SABORES (FLAVORS)
    // ========================================================
    flavorDimensions += "club"

    productFlavors {
        // SABOR 1: EL CLUB GÜEMES (El original)
        create("guemes") {
            dimension = "club"
            applicationId = "com.martinguemesfutbol.app"
            manifestPlaceholders["appName"] = "Club Martín Güemes"
        }
        
        // SABOR 2: LA DEMO GENÉRICA (El nuevo)
        create("generico") {
            dimension = "club"
            applicationId = "com.prosdodigital.generico" // ID único en Google Play para tu demo
            manifestPlaceholders["appName"] = "Demo ProsdoDigital"
        }

        // SABOR 3: CLUB FÁTIMA
        create("fatima") {
            dimension = "club"
            applicationId = "com.prosdodigital.fatima"
            manifestPlaceholders["appName"] = "Club Fátima"
        }

        // SABOR 4: CLUB LA LOMA
        create("laloma") {
            dimension = "club"
            applicationId = "com.prosdodigital.laloma"
            manifestPlaceholders["appName"] = "Club La Loma"
        }
    }
    // ========================================================

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?

            val storeFilePath = keystoreProperties["storeFile"] as String?
            storeFile = if (storeFilePath != null) file(storeFilePath) else null

            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            // Aplicamos la firma
            signingConfig = signingConfigs.getByName("release")

            // Optimizaciones
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1") 
}

configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.activity:activity:1.9.3")
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.core:core:1.15.0")
    }
}