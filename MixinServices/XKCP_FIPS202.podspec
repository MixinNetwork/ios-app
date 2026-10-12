Pod::Spec.new do |s|
  s.name = 'XKCP_FIPS202'
  s.version = '0.1.0'
  s.summary = 'FIPS 202 functions from the eXtended Keccak Code Package.'
  s.homepage = 'https://github.com/XKCP/XKCP'
  s.license = { :type => 'Mixed', :file => 'XKCP-LICENSE' }
  s.author = 'The XKCP developers'
  s.source = { :git => 'https://github.com/MixinNetwork/ios-app.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.vendored_frameworks = 'MixinServices/XKCP_FIPS202.xcframework'
end
