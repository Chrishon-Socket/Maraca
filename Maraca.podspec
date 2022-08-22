#
# Be sure to run `pod lib lint Maraca.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Maraca'
  s.version          = '1.0.7'
  s.summary          = 'Maraca bridges a web application with the CaptureSDK cocoapods framework.'
  s.swift_version    = '5.0'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Use Socket Mobile barcode scanners and RFID readers and writers with your web application by bridging iOS WKWebView with CaptureSDK
                       DESC

  s.homepage         = 'https://github.com/SocketMobile/Maraca'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Socket" => "developers@socketmobile.com" }
  s.source           = { :git => 'https://github.com/SocketMobile/Maraca.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '11.0'
  s.platform = :ios, "11.0"
  
  s.static_framework = true

  s.source_files = 'Classes/*.{h,m,swift}'
  
  s.pod_target_xcconfig = { 'ONLY_ACTIVE_ARCH' => 'YES' }
  s.user_target_xcconfig = { 'ONLY_ACTIVE_ARCH' => 'YES' } # not recommended but required to pass lint validation
  
  s.dependency 'CaptureSDK', '~>1.5'
end
