install! 'cocoapods',
:generate_multiple_pod_projects => true

platform :ios, '13.0'

def mixin_services
  pod 'libsignal-protocol-c', :git => 'https://github.com/MixinNetwork/libsignal-protocol-c.git'
  pod 'MixinServices', :path => './MixinServices', :testspecs => ['Tests']
end

target 'Mixin' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'Firebase/Core'
  pod 'Firebase/Analytics'
  pod 'Firebase/Performance'
  pod 'Firebase/Crashlytics'
  pod 'SnapKit'
  pod 'PhoneNumberKit', :git => 'https://github.com/marmelroy/PhoneNumberKit'
  pod 'R.swift'
  pod 'libwebp'
  pod 'SDWebImageLottieCoder'
  mixin_services
end

target 'MixinNotificationService' do
  use_frameworks!
  inhibit_all_warnings!
  
  pod 'R.swift'
  mixin_services
end

target 'MixinShare' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'R.swift'
  mixin_services
end

target 'MixinDebug' do
  use_frameworks!
  inhibit_all_warnings!

  pod "GCDWebServer"
  pod "GCDWebServer/WebDAV"
  mixin_services
end

target 'MixinTests' do
  use_frameworks!
  inhibit_all_warnings!

  mixin_services
end

# Prevent sqlite3 being linked to system integrated binary
# https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            xcconfig_path = config.base_configuration_reference.real_path
            xcconfig = File.read(xcconfig_path)
            xcconfig_mod = xcconfig.gsub(/ -l"sqlite3"/, "")
            File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
        end
    end
end
