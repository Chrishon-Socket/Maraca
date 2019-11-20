#
# Be sure to run `pod lib lint Maraca.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Maraca'
  s.version          = '0.1.0'
  s.summary          = 'Maraca bridges a web application with the SKTCapture cocoapod framework.'
  s.swift_version    = '5.0'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Use Socket Mobile barcode scanners and RFID readers and writers  with your web application by bridging iOS WKWebView with SKTCapture SDK
WKWebView with SKTCapture
                       DESC

  s.homepage         = 'https://github.com/Chrishon-Socket/Maraca'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Socket" => "developers@socketmobile.com" }
  s.source           = { :git => 'https://github.com/Chrishon-Socket/Maraca.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.3'
  s.platform = :ios, "9.3"

  s.source_files = 'Classes/*.{h,m,swift}'
  
  # s.resource_bundles = {
  #   'Maraca' => ['Maraca/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'SKTCapture', '~>1.1'
end
