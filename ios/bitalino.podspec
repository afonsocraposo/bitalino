#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bitalino.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bitalino'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin that integrates the communication with BITalino devices.'
  s.description      = <<-DESC
A Flutter plugin that integrates the communication with BITalino devices.
                       DESC
  s.homepage         = 'http://afonsoraposo.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Afonso Raposo' => 'afonsocraposo@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }

  s.preserve_paths = 'BITalinoBLE.framework'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework BITalinoBLE' }
  s.vendored_frameworks = 'BITalinoBLE.framework'
end
