FROM gradle:8.7.0-jdk17 as build

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="$PATH:/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/tools/bin"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends wget unzip && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/android-sdk/cmdline-tools \
 && cd /opt/android-sdk/cmdline-tools \
 && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdtools.zip \
 && unzip -q cmdtools.zip -d /opt/android-sdk/cmdline-tools \
 && rm cmdtools.zip \
 && mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest

RUN yes | sdkmanager --licenses > /dev/null \
 && sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

WORKDIR /workspace
COPY . /workspace

# Build the Android app (assemble debug)
RUN gradle -p mobile-android app:assembleDebug --no-daemon

# Output APK path hint
CMD ["/bin/bash", "-lc", "ls -lh mobile-android/app/build/outputs/apk/debug/"]

