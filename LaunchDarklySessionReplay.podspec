Pod::Spec.new do |s|
  s.name             = "LaunchDarklySessionReplay"
  s.version          = "0.14.0" # x-release-please-version
  s.summary          = "Session replay library for LaunchDarkly"
  s.description      = <<-DESC
                        Session Replay captures user interactions and screen recordings to help you understand how users interact with your application.
                       DESC
  s.homepage         = "https://github.com/launchdarkly/swift-launchdarkly-observability"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }
  s.author           = { "LaunchDarkly" => "sdks@launchdarkly.com" }
  s.platforms        = { :ios => "13.0" }
  s.source           = { :git => "https://github.com/launchdarkly/swift-launchdarkly-observability.git",
                         :tag => s.version.to_s }
  s.swift_version    = "5.9"

  s.default_subspec = 'LaunchDarklySessionReplay'

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'LD_COCOAPODS',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -package-name LaunchDarklyObservability'
  }

  s.dependency "LaunchDarklyObservability/LaunchDarklyObservability", s.version.to_s
  

  s.subspec "Common" do |ss|
    ss.source_files = "Sources/Common/**/*.{swift,h,m}"
  end

  s.subspec "LaunchDarklySessionReplay" do |ss|
    ss.source_files = "Sources/LaunchDarklySessionReplay/**/*.{swift,h,m}"
    ss.dependency "LaunchDarklySessionReplay/Common"
    ss.dependency "LaunchDarklyObservability/LaunchDarklyObservability"
  end
end
