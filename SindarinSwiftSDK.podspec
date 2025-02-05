Pod::Spec.new do |spec|

  spec.name         = "SindarinSwiftSDK"
  spec.version      = "1.0.0"
  spec.summary      = "SindarinSwiftSDK enables ultra-low latency conversational AI."
  spec.description  = "SindarinSwiftSDK enables ultra-low latency conversational AI. Visit https://sindarin.tech for more information."

  spec.platform     = :ios, '15.0'

  spec.homepage     = "https://github.com/sindarin-ventures/persona-client-swift"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Sindarin Ventures" => "support@sindarin.tech" }
  spec.source       = { :git => "https://github.com/sindarin-ventures/persona-client-swift.git", :tag => spec.version.to_s }

  spec.source_files  = "SindarinSwiftSDK/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.swift_version = "5.0"
  
  spec.dependency "Starscream", '4.0.6'
  spec.dependency "Socket.IO-Client-Swift", '~> 16.1.0'
end
