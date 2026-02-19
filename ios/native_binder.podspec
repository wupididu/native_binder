Pod::Spec.new do |s|
  s.name             = 'native_binder'
  s.version          = '0.0.1'
  s.summary          = 'Synchronous Dart to native (Kotlin/Swift) bridge via JNI and FFI.'
  s.description      = 'Synchronous bridge from Dart to Kotlin (Android) and Swift (iOS) using StandardMessageCodec. Supports String, Int, Double, Boolean, List, Map.'
  s.homepage         = 'https://github.com/native_binder'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Native Binder' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.dependency 'Flutter'
end
