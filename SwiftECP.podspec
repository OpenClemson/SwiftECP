Pod::Spec.new do |s|
  s.name             = "SwiftECP"
  s.version          = "3.0.0"
  s.summary          = "SwiftECP is a simple Shibboleth ECP client for iOS."
  s.description      = <<-DESC
                       Need Shibboleth login on your iOS app but don't want to use a webview? Don't want to deal with XML or read a spec? Use SwiftECP to do the work for you! SwiftECP is a spec-conformant Shibboleth ECP client for iOS. Simply provide credentials and a Shibboleth-protected resource URL and SwiftECP will hand you a Shibboleth cookie to attach to further requests or inject into a webview.
                       DESC
  s.homepage         = "https://github.com/OpenClemson/SwiftECP"
  s.license          = 'Apache 2.0'
  s.author           = { "Tyler Thompson" => "tpthomp@clemson.edu" }
  s.source           = { :git => "https://github.com/OpenClemson/SwiftECP.git", :tag => s.version.to_s }

  s.platform     = :ios, '9.0'
  s.requires_arc = true

  s.source_files = 'Pod/Source/**/*'

  s.dependency 'AEXML', '~> 2.0'
  s.dependency 'Alamofire', '~> 3.2.1'
  s.dependency 'ReactiveCocoa', '4.0.4-alpha-4'
  s.dependency 'XCGLogger', '~> 3.0'
end
