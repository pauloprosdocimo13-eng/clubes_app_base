plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- IMPORTS NECESARIOS (ESTO FALTABA) ---
import java.io.FileInputStream
import java.util.Properties
// -----------------------------------------

// Carga de key.properties
val keystoreProperties = Properties()
// Buscamos el archivo en la carpeta "android/" (rootProject)
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.martinguemesfutbol.app" // Tu ID de paquete
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

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
        applicationId = "com.martinguemesfutbol.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 21
        versionName = "1.0.1"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Leemos las propiedades y las convertimos a String
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?

            // Verificamos si existe la ruta del archivo y lo cargamos
            val storeFilePath = keystoreProperties["storeFile"] as String?
            storeFile = if (storeFilePath != null) file(storeFilePath) else null

            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Aplicamos la firma
            signingConfig = signingConfigs.getByName("release")

            // Optimizaciones
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:...")
    
    // ... otras dependencias ...

    implementation("androidx.multidex:multidex:2.0.1") // <--- ASÍ CON PARÉNTESIS Y COMILLAS
}
