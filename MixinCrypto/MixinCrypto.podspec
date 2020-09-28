#
# Be sure to run `pod lib lint MixinCrypto.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MixinCrypto'
  s.version          = '0.1.0'
  s.summary          = 'MixinCrypto is a cryptographic library for authentication.'

  s.description      = <<-DESC
  MixinCrypto is a cryptographic library for authentication.
                       DESC

  s.homepage         = 'https://github.com/wuyuehyang/MixinCrypto'
  s.license          = { :type => 'GNU GPL v3', :file => 'LICENSE' }
  s.author           = { 'wuyuehyang' => 'wuyuehyang@mixin.one' }
  s.source           = { :git => 'https://github.com/wuyuehyang/MixinCrypto.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.static_framework = true

  s.source_files = 'Ed25519/*'

  s.dependency 'BoringSSL'
end
