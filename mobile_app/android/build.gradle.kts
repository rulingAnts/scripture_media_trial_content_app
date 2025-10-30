import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// Force consistent JVM targets for all Kotlin and Java compilation tasks across subprojects
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        kotlinOptions {
            // Some older plugins (e.g. receive_sharing_intent) still compile Java at 1.8.
            // Align Kotlin per-module to avoid mismatches with their JavaCompile tasks.
            jvmTarget = if (project.name == "receive_sharing_intent") "1.8" else "17"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
