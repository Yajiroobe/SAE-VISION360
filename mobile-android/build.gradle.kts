// Root build file
allprojects {
  // repositories defined in settings.gradle.kts
}

tasks.register("clean", Delete::class) {
  delete(layout.buildDirectory)
}

