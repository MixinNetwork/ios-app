install! 'cocoapods',
:generate_multiple_pod_projects => true

platform :ios, '15.0'

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
  pod 'AppsFlyerFramework'
  pod 'PhoneNumberKit', :git => 'https://github.com/marmelroy/PhoneNumberKit'
  pod 'libwebp'
  pod 'SDWebImageLottieCoder'
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit'
  pod 'SDWebImageSVGKitPlugin'
  mixin_services
end

target 'MixinNotificationService' do
  use_frameworks!
  inhibit_all_warnings!
  
  mixin_services
end

target 'MixinShare' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'SDWebImageLottieCoder'
  mixin_services
end

target 'MixinDebug' do
  use_frameworks!
  inhibit_all_warnings!
  mixin_services
end
