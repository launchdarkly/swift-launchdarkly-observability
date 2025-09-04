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
  spec.source       = { :git => spec.homepage + '.git', :branch => "feature/cocoapods" }
  spec.default_subspec = "LaunchDarklyObservability"

  # Targets
  spec.subspec 'LaunchDarklyObservability' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
  end

  spec.subspec 'API' do |ld|
    ld.source_files = "Sources/#{ld.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    ld.dependency "LaunchDarklyObservability/OpenTelemetrySdk"
  end

  spec.subspec 'OpenTelemetrySdk' do |ld|
    ld.dependency "OpenTelemetry-Swift-Sdk", "2.0.0"
  end

end