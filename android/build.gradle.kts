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
    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val getNamespace = androidExtension.javaClass.getMethod("getNamespace")
                if (getNamespace.invoke(androidExtension) == null) {
                    val setNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = "com.example.${name.replace('-', '_')}"
                    setNamespace.invoke(androidExtension, ns)
                }
            } catch (e: Exception) {
                // ignore
            }
            try {
                val method = androidExtension.javaClass.methods.firstOrNull { it.name == "compileSdkVersion" && it.parameterTypes.size == 1 }
                    ?: androidExtension.javaClass.methods.firstOrNull { it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 }
                    ?: androidExtension.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterTypes.size == 1 }
                if (method != null) {
                    if (method.parameterTypes[0] == Int::class.javaPrimitiveType || method.parameterTypes[0] == java.lang.Integer::class.java) {
                        method.invoke(androidExtension, 35)
                    } else if (method.parameterTypes[0] == String::class.java) {
                        method.invoke(androidExtension, "android-35")
                    }
                }
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
