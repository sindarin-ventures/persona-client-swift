Pod::Spec.new do |spec|

  spec.name         = "SindarinSwiftSDK"
  spec.version      = "1.0.0"
  spec.summary      = "A short description of SindarinSwiftSDK."
  spec.description  = "A complete description of SindarinSwiftSDK"

  spec.platform     = :ios, "12.1"
  
  spec.homepage     = "http://EXAMPLE/SindarinSwiftSDK"
  spec.license      = "MIT"
  spec.author       = { "Bohdan Hasyn" => "bohdan.hasyn@gmail.com" }
  spec.source       = { :path => '.' }
  
  spec.source_files = "SindarinSwiftSDK"
  spec.exclude_files = "Classes/Exclude"
  spec.swift_version = "5"
  spec.dependency "Socket.IO-Client-Swift", '~> 16.1.0'
end
