Pod::Spec.new do |s|
  s.name             = "LaunchDarklySessionReplay"
  s.version          = "0.27.0" # x-release-please-version
  s.summary          = "iOS Session Replay Plugin for LaunchDarkly."
  s.description      = <<-DESC
                        LaunchDarkly is the feature management platform that software teams use to build better software, faster.
                       DESC
  s.homepage         = "https://github.com/launchdarkly/swift-launchdarkly-observability"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }
  s.author           = { "LaunchDarkly" => "sdks@launchdarkly.com" }
  s.platforms        = { :ios => "13.0" }
  s.source           = { :git => "https://github.com/launchdarkly/swift-launchdarkly-observability.git",
                         :tag => s.version.to_s }
  s.swift_version    = "5.9"

  s.default_subspec  = 'LaunchDarklySessionReplay'

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LD_COCOAPODS'
  }

  s.user_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO' }

  # SessionReplayC — pre-built XCFramework
  s.subspec "SessionReplayC" do |ss|
    ss.vendored_frameworks = "Frameworks/SessionReplayC.xcframework"
  end

  # LaunchDarklySessionReplay — Swift target
  s.subspec "LaunchDarklySessionReplay" do |ss|
    ss.source_files = "Sources/LaunchDarklySessionReplay/**/*.{swift,h,m}"
    ss.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LD_COCOAPODS',
      'OTHER_SWIFT_FLAGS'                   => '$(inherited) -package-name LaunchDarklyObservability'
    }
    ss.dependency "LaunchDarklySessionReplay/SessionReplayC"
    ss.dependency "LaunchDarklyObservability"
  end

end
