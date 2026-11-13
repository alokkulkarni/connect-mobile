# The banking app's call module: Amazon Connect web calling through the Amazon Chime SDK, audio only.
Pod::Spec.new do |s|
  s.name         = 'connect-call'
  s.version      = '1.0.0'
  s.summary      = 'Audio-only Amazon Connect web calling for the banking app.'
  s.homepage     = 'https://example.invalid/connect-call'
  s.license      = { :type => 'UNLICENSED' }
  s.author       = 'Banking app'
  s.platforms    = { :ios => '15.1' }
  s.source       = { :path => '.' }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.swift_version = '5.0'
  # React Native's own helper sets up the React dependencies for this version (old and new architecture).
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency 'React-Core'
  end
  s.dependency 'AmazonChimeSDK', '0.27.4'        # brings AmazonChimeSDKMedia 0.25.4
end
