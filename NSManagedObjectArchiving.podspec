Pod::Spec.new do |spec|
  spec.name         = 'SNRFetchedResultsController'
  spec.version      = '0.1.0'
  spec.license      = { :type => 'MIT' }
  spec.homepage     = 'https://github.com/indragiek/SNRFetchedResultsController'
  spec.authors      = 'Robert Payne', 'Micha Mazaheri'
  spec.summary      = 'An easy way to archive and unarchive NSManagedObjects.'
  spec.source       = { :git => 'https://github.com/luckymarmot/NSManagedObjectArchiving.git', :tag => s.version }
  spec.source_files = 'NSManagedObjectArchiving.{h,m}'
  spec.framework    = 'SystemConfiguration'
  spec.requires_arc = true
end
