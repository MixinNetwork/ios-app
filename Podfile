install! 'cocoapods',
:generate_multiple_pod_projects => true,
:incremental_installation => true

platform :ios, '11.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'Mixin' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'Alamofire'
  pod 'Firebase/Core'
  pod 'Firebase/MLVision'
  pod 'Firebase/MLVisionBarcodeModel'
  pod 'Firebase/MLVisionFaceModel'
  pod 'SDWebImage'
  pod 'SDWebImageYYPlugin/YYImage'
  pod 'YYImage/WebP'
  pod 'SnapKit'
  pod 'PhoneNumberKit'
  pod 'RSKImageCropper'
  pod 'Zip', '~> 1.1.0'
  pod 'GoogleWebRTC'
  pod 'AlignedCollectionViewFlowLayout'
  pod 'R.swift'
  pod 'SignalProtocolC', :git => 'https://github.com/MixinNetwork/SignalProtocolC.git', :submodules => true
  pod 'WCDB.swift', :git => 'https://github.com/MixinNetwork/wcdb.git', :branch => 'bugfix/fts'
  pod 'MixinServices', :path => './MixinServices'
end
