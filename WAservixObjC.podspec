Pod::Spec.new do |s|
  s.name             = 'WAservixObjC'
  s.version          = '1.0.0'
  s.summary          = 'WAservix WhatsApp API Gateway: official Objective-C client by Tekservix'
  s.description      = 'WAservix WhatsApp API Gateway: official Objective-C client by Tekservix. Send WhatsApp text, images, documents and locations from your own number, check message status, manage contacts and groups and verify webhooks. No dependencies beyond Foundation. Requires a Tekservix account with WAservix.'
  s.homepage         = 'https://tekservix.com/waservix/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tekservix' => 'support@tekservix.com' }
  s.source           = { :git => 'https://github.com/TekservixHQ/waservix-swift.git', :tag => "objc-v#{s.version}" }
  s.documentation_url = 'https://tekservix.com/waservix/docs/'
  s.ios.deployment_target     = '12.0'
  s.osx.deployment_target     = '10.13'
  s.tvos.deployment_target    = '12.0'
  s.watchos.deployment_target = '4.0'
  s.requires_arc     = true
  s.source_files     = 'ObjC/WAservixObjC/**/*.{h,m}'
  s.public_header_files = 'ObjC/WAservixObjC/**/*.h'
  s.frameworks       = 'Foundation'

  s.test_spec 'Tests' do |t|
    t.source_files = 'ObjC/Tests/**/*.m'
    t.frameworks = 'XCTest'
    t.platforms = { :ios => '12.0', :osx => '10.13' }
  end
end
