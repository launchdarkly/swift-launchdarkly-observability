Pod::Spec.new do |s|
  s.name             = "LaunchDarklyObservability"
  s.version          = "0.24.0" # x-release-please-version
  s.summary          = "iOS Observability Plugin for LaunchDarkly."
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

  s.default_subspec  = 'LaunchDarklyObservability'

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LD_COCOAPODS'
  }

  # KSCrash ships resource bundles inside its framework. Xcode's user script
  # sandboxing blocks the CocoaPods embed script from copying them at build time,
  # causing rsync "Operation not permitted" errors. Disabling it on the consumer
  # target is the standard workaround until KSCrash resolves this upstream.
  s.user_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO' }

  # --- LaunchDarklyObservability (main target) ---
  s.subspec "LaunchDarklyObservability" do |ss|
    ss.source_files = [
      "Sources/LaunchDarklyObservability/**/*.{swift,h,m}",
      "Sources/ObjCBridge/**/*.{h,m}"
    ]
    ss.public_header_files = "Sources/ObjCBridge/*.h"
    ss.dependency "LaunchDarklyObservability/Common"
    ss.dependency "LaunchDarklyObservability/OpenTelemetryProtocolExporterCommon"
    ss.dependency "LaunchDarklyObservability/URLSessionInstrumentation"
    ss.dependency "LaunchDarklyObservability/SDKResourceExtension"
    ss.dependency "LaunchDarklyObservability/OpenTelemetry"
    ss.dependency "LaunchDarklyObservability/Misc"
  end

  # Common sources + LaunchDarkly SDK dependency
  s.subspec "Common" do |ss|
    ss.source_files = "Sources/Common/**/*.{swift,h,m}"
    ss.dependency 'LaunchDarkly', '~> 11.1.0'
  end

  # OpenTelemetryProtocolExporterCommon subspec
  s.subspec "OpenTelemetryProtocolExporterCommon" do |ss|
    ss.source_files = "Sources/OpenTelemetry/OpenTelemetryProtocolExporterCommon/**/*.{swift,h,m}"
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
    ss.dependency 'SwiftProtobuf'
  end

  # NetworkStatus subspec
  s.subspec "NetworkStatus" do |ss|
    ss.source_files = "Sources/OpenTelemetry/Instrumentation/NetworkStatus/**/*.{swift,h,m}"
    ss.dependency 'OpenTelemetry-Swift-Api', '~> 2.3.0'
    ss.frameworks = 'CoreTelephony'
  end

  # URLSessionInstrumentation subspec
  s.subspec "URLSessionInstrumentation" do |ss|
    ss.source_files = "Sources/OpenTelemetry/Instrumentation/URLSession/**/*.{swift,h,m}"
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
    ss.dependency "LaunchDarklyObservability/NetworkStatus"
  end

  # SDKResourceExtension subspec
  s.subspec "SDKResourceExtension" do |ss|
    ss.source_files = "Sources/OpenTelemetry/Instrumentation/SDKResourceExtension/**/*.{swift,h,m}"
    ss.exclude_files = "Sources/OpenTelemetry/Instrumentation/SDKResourceExtension/README.md"
    ss.dependency "LaunchDarklyObservability/OpenTelemetry"
  end

  # OpenTelemetry API + SDK
  s.subspec 'OpenTelemetry' do |ss|
    ss.dependency 'OpenTelemetry-Swift-Api', '~> 2.3.0'
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
  end

  # KSCrash (Installations product maps to the KSCrash pod)
  s.subspec 'Misc' do |ss|
    ss.dependency 'KSCrash'
  end

end
