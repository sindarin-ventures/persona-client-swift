# Uncomment the next line to define a global platform for your project
platform :ios, '15.6'

target 'SindarinSwiftSDK' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SindarinSwiftSDK
  pod 'Socket.IO-Client-Swift'

  target 'SindarinSwiftSDKTests' do
    "$(inherited)"
  end
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Do either this:
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        # or this:
        config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      end
    end
  end

end
