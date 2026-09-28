Pod::Spec.new do |s|
  s.name             = "LaunchDarklyCrashReporting"
  s.version          = "0.55.1" # x-release-please-version
  s.summary          = "KSCrash crash reporting for the LaunchDarkly iOS Observability Plugin."
  s.description      = <<-DESC
                        LaunchDarkly is the feature management platform that software teams use to build better software, faster.
                       DESC
  s.homepage         = "https://github.com/launchdarkly/swift-launchdarkly-observability"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }
  s.author           = { "LaunchDarkly" => "sdks@launchdarkly.com" }
  s.platforms        = { :ios => "15.0" }
  s.source           = { :git => "https://github.com/launchdarkly/swift-launchdarkly-observability.git",
                         :tag => s.version.to_s }
  s.swift_version    = "5.9"

  s.source_files     = "Sources/LaunchDarklyCrashReporting/**/*.{swift,h,m}"

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LD_COCOAPODS'
  }

  # KSCrash ships resource bundles inside its framework. Xcode's user script
  # sandboxing blocks the CocoaPods embed script from copying them at build time,
  # causing rsync "Operation not permitted" errors. Disabling it on the consumer
  # target is the standard workaround until KSCrash resolves this upstream.
  s.user_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO' }

  s.dependency "LaunchDarklyObservability", s.version.to_s
  s.dependency "KSCrash", ">= 2.5.0", "< 3.0.0"
end
