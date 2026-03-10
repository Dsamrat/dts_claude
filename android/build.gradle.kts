// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    dependencies {
        // ✅ Add Firebase Google Services plugin classpath
        classpath("com.google.gms:google-services:4.3.15")

    }

    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Repositories for all projects
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Custom build output directory (optional)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
