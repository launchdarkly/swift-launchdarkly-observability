Pod::Spec.new do |s|
  s.name             = "LaunchDarklyOtel"
  s.version          = "0.52.1" # x-release-please-version
  s.summary          = "iOS OpenTelemetry Plugin for LaunchDarkly."
  s.description      = <<-DESC
                        Records logs, spans, metrics and track events through LDObserve and exports
                        them over OTLP. Installs no swizzling and no crash handlers, so it can run
                        alongside another observability SDK. Use LaunchDarklyObservability instead
                        for automatic instrumentation and crash reporting.
                       DESC
  s.homepage         = "https://github.com/launchdarkly/swift-launchdarkly-observability"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }
  s.author           = { "LaunchDarkly" => "sdks@launchdarkly.com" }
  s.platforms        = { :ios => "13.0" }
  s.source           = { :git => "https://github.com/launchdarkly/swift-launchdarkly-observability.git",
                         :tag => s.version.to_s }
  s.swift_version    = "5.9"

  s.default_subspec  = 'LaunchDarklyOtel'

  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LD_COCOAPODS'
  }

  # --- LaunchDarklyOtel (main target) ---
  s.subspec "LaunchDarklyOtel" do |ss|
    ss.source_files = "Sources/LaunchDarklyOtel/**/*.{swift,h,m}"
    ss.dependency "LaunchDarklyOtel/Common"
    ss.dependency "LaunchDarklyOtel/JSONExporters"
    ss.dependency "LaunchDarklyOtel/SDKResourceExtension"
    ss.dependency "LaunchDarklyOtel/OpenTelemetry"
    ss.dependency 'LaunchDarkly', '~> 11.5'
  end

  # Common sources + LaunchDarkly SDK dependency (used by GraphQLClient's ld_gzip)
  s.subspec "Common" do |ss|
    ss.source_files = "Sources/Common/**/*.{swift,h,m}"
    ss.dependency 'LaunchDarkly', '~> 11.5'
  end

  # JSONExporters subspec — OTLP/JSON wire-format models and adapters
  s.subspec "JSONExporters" do |ss|
    ss.source_files = "Sources/OpenTelemetry/JSONExporters/**/*.{swift,h,m}"
    ss.dependency 'OpenTelemetry-Swift-Api', '~> 2.3.0'
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
  end

  # SDKResourceExtension subspec
  s.subspec "SDKResourceExtension" do |ss|
    ss.source_files = "Sources/OpenTelemetry/Instrumentation/SDKResourceExtension/**/*.{swift,h,m}"
    ss.exclude_files = "Sources/OpenTelemetry/Instrumentation/SDKResourceExtension/README.md"
    ss.dependency "LaunchDarklyOtel/OpenTelemetry"
  end

  # OpenTelemetry API + SDK
  s.subspec 'OpenTelemetry' do |ss|
    ss.dependency 'OpenTelemetry-Swift-Api', '~> 2.3.0'
    ss.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.3.0'
  end

end
