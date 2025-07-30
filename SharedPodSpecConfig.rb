module SharedPodSpecConfig
  VERSION = '1.5.1'
  GITHUB_PAGE = 'https://github.com/Octopus-Community/octopus-sdk-swift'
  SOURCE = { :git => "#{GITHUB_PAGE}.git", :tag => "v#{VERSION}" }
  LICENSE = { :file => 'LICENSE.md' }
  AUTHOR = { 'Djavan Bertrand' => 'djavan.bertrand@octopuscommunity.com' }
  IOS_DEPLOYMENT_TARGET = '13.0'
  SWIFT_VERSION = '5.9'
end