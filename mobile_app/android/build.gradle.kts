import org.jetbrains.kotlin.gradle.dsl.JvmTarget
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

// Force consistent JVM targets for all Kotlin and Java compilation tasks across subprojects.
// Kotlin 2.2 removed the kotlinOptions DSL — it is a hard error, not a warning — so this
// uses compilerOptions. See https://kotl.in/u1r8ln
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            // Some older plugins (e.g. receive_sharing_intent) still compile Java at 1.8.
            // Align Kotlin per-module to avoid mismatches with their JavaCompile tasks.
            jvmTarget.set(
                if (project.name == "receive_sharing_intent") JvmTarget.JVM_1_8 else JvmTarget.JVM_17
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
