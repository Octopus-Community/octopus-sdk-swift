require_relative 'SharedPodSpecConfig'

Pod::Spec.new do |spec|
  spec.name         = 'OctopusCommunityCore'
  spec.module_name  = 'OctopusCore'
  spec.summary      = 'Octopus core model objects. You should not use directly this pod. You should use Octopus and OctopusUI.'
  spec.version      = SharedPodSpecConfig::VERSION
  spec.homepage     = SharedPodSpecConfig::GITHUB_PAGE
  spec.license      = SharedPodSpecConfig::LICENSE
  spec.author       = SharedPodSpecConfig::AUTHOR
  spec.source       = SharedPodSpecConfig::SOURCE
  
  spec.ios.deployment_target = SharedPodSpecConfig::IOS_DEPLOYMENT_TARGET
  spec.swift_version = SharedPodSpecConfig::SWIFT_VERSION
  
  spec.source_files = 'Sources/OctopusCore/**/*.swift'

  spec.resource_bundles = {
      'OctopusCore' => ['Sources/OctopusCore/Persistence/**/*.{xcdatamodeld}']
  }

  spec.dependency 'KeychainAccess'
  spec.dependency 'OctopusCommunityRemoteClient', SharedPodSpecConfig::VERSION
  spec.dependency 'OctopusCommunityGrpcModels', SharedPodSpecConfig::VERSION
  spec.dependency 'OctopusCommunityDependencyInjection', SharedPodSpecConfig::VERSION
end
