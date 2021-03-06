Pod::Spec.new do |s|
  s.name         = 'NSManagedObjectArchiving'
  s.version      = '0.1.1'
  s.license      = { :type => 'MIT' }
  s.homepage     = 'https://github.com/luckymarmot/NSManagedObjectArchiving'
  s.authors      = 'Robert Payne', 'Micha Mazaheri'
  s.summary      = 'An easy way to archive and unarchive NSManagedObjects.'
  s.source       = { :git => 'https://github.com/luckymarmot/NSManagedObjectArchiving.git', :tag => s.version }
  s.source_files = 'NSManagedObjectArchiving.{h,m}'
  s.frameworks   = 'CoreData'
  s.requires_arc = true
  s.osx.deployment_target = '10.10'
  s.ios.deployment_target = '10.0'
end
