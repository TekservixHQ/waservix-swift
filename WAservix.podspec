Pod::Spec.new do |s|
  s.name             = 'WAservix'
  s.version          = '1.0.1'
  s.summary          = 'WAservix WhatsApp API Gateway: official Swift client by Tekservix'
  s.description      = 'WAservix WhatsApp API Gateway: official Swift client by Tekservix. Send WhatsApp text, media, locations and polls from your own number, check status, manage contacts and groups. Requires a Tekservix account with WAservix.'
  s.homepage         = 'https://tekservix.com/waservix'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tekservix' => 'support@tekservix.com' }
  s.source           = { :git => 'https://github.com/TekservixHQ/waservix-swift.git', :tag => "v#{s.version}" }
  s.documentation_url = 'https://tekservix.com/waservix/docs/'
  s.swift_versions   = ['5.7', '5.8', '5.9', '5.10', '6.0']
  s.ios.deployment_target     = '13.0'
  s.osx.deployment_target     = '10.15'
  s.tvos.deployment_target    = '13.0'
  s.watchos.deployment_target = '6.0'
  s.source_files     = 'Sources/WAservix/**/*.swift'
  s.frameworks       = 'Foundation'
end
