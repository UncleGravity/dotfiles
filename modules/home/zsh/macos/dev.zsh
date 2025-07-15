#TODO: Get rid of this file altogether. Dev environments like this should be managed by Nix

# JAVA_HOME Setup
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home

# Android SDK Setup
# export ANDROID_SDK_ROOT=$HOMEBREW_PREFIX/share/android-commandlinetools # If installed with Homebrew (no Android Studio)
# export ANDROID_HOME=$HOMEBREW_PREFIX/share/android-commandlinetools # If installed with Homebrew (no Android Studio)
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk # If installed with Android Studio
export ANDROID_HOME=$HOME/Library/Android/sdk     # If installed with Android Studio
export NDK=$ANDROID_HOME/ndk-bundle
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Ruby version manager setup
# export GEM_HOME=$HOME/.gem
# export PATH=$GEM_HOME/bin:$PATH
# eval "$(rbenv init - zsh)"

# N Package Manager Setup
export N_PREFIX="$HOME/n"
[[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin" # Added by n-install (see http://git.io/n-install-repo).
