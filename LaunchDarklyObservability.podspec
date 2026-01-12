Pod::Spec.new do |s|
  s.name             = "LaunchDarklyObservability"
  s.version          = "0.15.2" # x-release-please-version
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

  s.default_subspec = 'LaunchDarklyObservability'

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'LD_COCOAPODS',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -package-name LaunchDarklyObservability'
  }

  # Main LaunchDarklyObservability subspec
  s.subspec "LaunchDarklyObservability" do |ss|
    ss.source_files = [
        "Sources/#{ss.module_name}/**/*.{swift,h,m}",
        "Sources/ObjCBridge/**/*.{h,m}"
    ]
    ss.public_header_files = "Sources/ObjCBridge/*.h"
    ss.dependency "LaunchDarklyObservability/Core"
  end

  # Observability Core

  s.subspec "Core" do |ss|
    #ss.source_files = "Sources/#{ss.module_name}/**/*.{swift,h,m}"
    ss.dependency "LaunchDarklyObservability/OpenTelemetry"
    ss.dependency "LaunchDarklyObservability/Misc"
    ss.dependency "LaunchDarklyObservability/Internal"
  end

  # Internal

  s.subspec "Internal" do |ss|
    ss.dependency "LaunchDarklyObservability/Common"
    #ss.dependency "LaunchDarklyObservability/ObjCBridge"
    ss.dependency "LaunchDarklyObservability/OpenTelemetryProtocolExporterCommon"
    ss.dependency "LaunchDarklyObservability/NetworkStatus"
    ss.dependency "LaunchDarklyObservability/URLSessionInstrumentation"    
  end

  s.subspec "Common" do |ss|
    ss.source_files = "Sources/Common/**/*.{swift,h,m}"
    ss.dependency 'DataCompression'
  end

  # OpenTelemetryProtocolExporterCommon subspec
  s.subspec "OpenTelemetryProtocolExporterCommon" do |ss|
    ss.source_files = "Sources/OpenTelemetry/OpenTelemetryProtocolExporterCommon/**/*.{swift,h,m}"
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
    #ss.dependency 'SwiftLog'
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

  # External

  s.subspec 'OpenTelemetry' do |ss|
    ss.dependency 'OpenTelemetry-Swift-Api', '~> 2.3.0'
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
  end

  s.subspec 'Misc' do |ss|
    ss.dependency 'DataCompression', '~> 3.8.0'
    ss.dependency 'KSCrash'
    ss.dependency 'LaunchDarkly', '~> 9.15'
  end

end