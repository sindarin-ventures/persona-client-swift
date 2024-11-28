Pod::Spec.new do |spec|

  spec.name         = "SindarinSwiftSDK"
  spec.version      = "1.0.0"
  spec.summary      = "SindarinSwiftSDK is a powerful SDK for processing Sindarin language."
  spec.description  = "SindarinSwiftSDK is designed to provide developers with tools to process and manage Sindarin language data effectively."

  spec.platform     = :ios, '12.0'

  spec.homepage     = "https://github.com/yourusername/SindarinSwiftSDK"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Bohdan Hasyn" => "bohdan.hasyn@gmail.com" }
  spec.source       = { :git => "https://github.com/yourusername/SindarinSwiftSDK.git", :tag => spec.version.to_s }

  spec.source_files  = "SindarinSwiftSDK/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.swift_version = "5.0"
  
  spec.dependency "Starscream", '4.0.6'
  spec.dependency "Socket.IO-Client-Swift", '~> 16.1.0'
end
