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

  pod 'SnapKit'
  pod 'PhoneNumberKit', :git => 'https://github.com/marmelroy/PhoneNumberKit'
  pod 'libwebp'
  pod 'SDWebImageLottieCoder'
  pod 'Frames', '~> 4'
  pod 'Checkout3DS', :git => 'git@github.com:checkout/checkout-3ds-sdk-ios.git'
  mixin_services
  
  post_install do |installer|
    installer.generated_projects.each do |project|
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        end
      end
    end
  end
end

target 'MixinNotificationService' do
  use_frameworks!
  inhibit_all_warnings!
  
  mixin_services
end

target 'MixinShare' do
  use_frameworks!
  inhibit_all_warnings!

  mixin_services
end

target 'MixinDebug' do
  use_frameworks!
  inhibit_all_warnings!

  pod "GCDWebServer"
  pod "GCDWebServer/WebDAV"
  mixin_services
end
