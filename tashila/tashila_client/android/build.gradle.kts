allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    val manifestFile = file("src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        try {
            val text = manifestFile.readText()
            if (text.contains("package=")) {
                val updated = text.replace(Regex("""package="[^"]+""""), "")
                manifestFile.writeText(updated)
            }
        } catch (e: Exception) {
            println("Failed to patch manifest for ${project.name}: ${e.message}")
        }
    }
}

subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null && android.namespace == null) {
            android.namespace = "com.tashila.${project.name.replace("package", "pkg").replace("-", ".").replace("_", ".")}"
        }
    }
    plugins.withId("com.android.application") {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null && android.namespace == null) {
            android.namespace = "com.tashila.${project.name.replace("package", "pkg").replace("-", ".").replace("_", ".")}"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
