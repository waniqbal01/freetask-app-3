buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
// classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    configurations.all {
        resolutionStrategy {
            // Force byte-buddy to use a Java 17 compatible version
            // Version 1.17.6 was compiled with Java 24 (class file major version 68)
            force("net.bytebuddy:byte-buddy:1.14.18")
            force("net.bytebuddy:byte-buddy-agent:1.14.18")
        }
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}


