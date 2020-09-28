install! 'cocoapods',
:generate_multiple_pod_projects => true

platform :ios, '11.0'

def mixin_services
  pod 'libsignal-protocol-c', :git => 'https://github.com/MixinNetwork/libsignal-protocol-c.git'
  pod 'WCDB.swift', :git => 'https://github.com/MixinNetwork/wcdb.git', :branch => 'bugfix/fts'
  pod 'SwiftyMarkdown', :git => 'https://github.com/wuyuehyang/SwiftyMarkdown.git'
  pod 'lottie-ios', :git => 'https://github.com/airbnb/lottie-ios.git', :branch => 'lottie/objectiveC'
  pod 'YYImage', :git => 'https://github.com/wuyuehyang/YYImage.git'
  pod 'MixinCrypto', :path => './MixinCrypto'
  pod 'MixinServices', :path => './MixinServices'
end

target 'Mixin' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'Firebase/Core'
  pod 'Firebase/Analytics'
  pod 'Firebase/Performance'
  pod 'Firebase/Crashlytics'
  pod 'SnapKit'
  pod 'PhoneNumberKit', :git => 'https://github.com/the0neyouseek/PhoneNumberKit'
  pod 'RSKImageCropper'
  pod 'AlignedCollectionViewFlowLayout'
  pod 'R.swift'
  pod 'Highlightr', :git => 'https://github.com/wuyuehyang/Highlightr.git', :branch => 'master'
  pod 'Texture', :git => 'https://github.com/TextureGroup/Texture.git', :branch => 'master'
  pod 'TexturedMaaku', :git => 'https://github.com/wuyuehyang/TexturedMaaku.git', :branch => 'mixin'
  pod 'TexturedMaaku/SyntaxColors', :git => 'https://github.com/wuyuehyang/TexturedMaaku.git', :branch => 'mixin'
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

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      config.build_settings.delete 'VALID_ARCHS'
    end
  end
end
