Pod::Spec.new do |s|
  s.name = 'TIP'
  s.version = '0.1.0'
  s.summary = 'TIP binary library for Mixin.'
  s.homepage = 'https://github.com/MixinNetwork/ios-app'
  s.license = { :type => 'GNU GPL v3', :file => 'LICENSE' }
  s.author = { 'wuyueyang' => 'wuyueyang@mixin.one' }
  s.source = { :git => 'https://github.com/MixinNetwork/ios-app.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.vendored_frameworks = 'MixinServices/tip.xcframework'
end
