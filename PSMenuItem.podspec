Pod::Spec.new do |s|
  s.name = 'PSMenuItem'
  s.version = '1.0.0'
  s.summary = 'A block based UIMenuItem subclass.'
  s.homepage = 'https://github.com/steipete/PSMenuItem'
  s.license = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.author = 'Peter Steinberger', 'steipete@gmail.com'
  s.source = {
    :git => 'https://github.com/steipete/PSMenuItem.git',
    :tag => s.version.to_s
  }
  s.platform = :ios, '4.3'
  s.source_files = '*.{h,m}'
  s.frameworks = 'UIKit'
  s.requires_arc = true
end
