Pod::Spec.new do |spec|
  spec.name         = "LaunchDarklyObservability"
  spec.version      = "0.2.1"
  spec.summary      = "iOS Observability Plugin for LaunchDarkly."
  spec.description  = <<-DESC
                   LaunchDarkly is the feature management platform that software teams use to build better software, faster.
                   DESC

  spec.homepage     = "https://github.com/launchdarkly/swift-launchdarkly-observability"

  spec.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }

  spec.author             = { "LaunchDarkly" => "sdks@launchdarkly.com" }

  spec.ios.deployment_target = "16.0"
  spec.swift_version = "5.9"
  #spec.source       = { :git => spec.homepage + '.git', :tag => spec.version }
  spec.source       = { :git => spec.homepage + '.git', :branch => "feature/pods" }
  #spec.default_subspec = "LaunchDarklyObservability"

spec.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'LD_COCOAPODS'
  }


  # Targets
  #spec.subspec 'LaunchDarklyObservability' do |ld|
  #  ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
  #  ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
  #end

  spec.subspec 'API' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
  end

  spec.subspec 'Common' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
  end

  spec.subspec 'CrashReporter' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
  end

  spec.subspec 'CrashReporterLive' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    ld.dependency "LaunchDarklyObservability/CrashReporter"
    ld.dependency "LaunchDarklyObservability/Common"
    ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
    ld.dependency "KSCrash"
    #ld.dependency "KSCrash/Installations"
  end

  spec.subspec 'Observability' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    ld.dependency "LaunchDarklyObservability/Common"
    ld.dependency "LaunchDarklyObservability/API"
    ld.dependency "LaunchDarklyObservability/CrashReporter"
    ld.dependency "LaunchDarklyObservability/CrashReporterLive"
    ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
  end

  spec.subspec 'OpenTelemetrySdk' do |ld|
    ld.dependency "OpenTelemetry-Swift-Sdk", "2.0.0"
    ld.dependency "OpenTelemetry-Swift-Api", "2.0.0"
    ld.dependency "OpenTelemetry-Swift-SdkResourceExtension", "2.0.0"
    ld.dependency "OpenTelemetry-Swift-Instrumentation-URLSession", "2.0.0"
    ld.dependency "OpenTelemetry-Swift-Protocol-Exporter-Http", "2.0.0"
  end
  
end