require_relative 'SharedPodSpecConfig'

Pod::Spec.new do |spec|
  spec.name         = 'OctopusCore'
  spec.summary      = 'Octopus core model objects. You should not use directly this pod. You should use Octopus and OctopusUI.'
  spec.version      = SharedPodSpecConfig::VERSION
  spec.homepage     = SharedPodSpecConfig::GITHUB_PAGE
  spec.license      = SharedPodSpecConfig::LICENSE
  spec.author       = SharedPodSpecConfig::AUTHOR
  spec.source       = SharedPodSpecConfig::SOURCE
  
  spec.ios.deployment_target = SharedPodSpecConfig::IOS_DEPLOYMENT_TARGET
  spec.swift_version = SharedPodSpecConfig::SWIFT_VERSION
  
  spec.source_files = 'Sources/OctopusCore/**/*.swift'

  spec.resources = [
      'Sources/OctopusCore/Persistence/Database/OctopusModel/OctopusModel.xcdatamodeld',
      'Sources/OctopusCore/Persistence/Database/OctopusTracking/OctopusTracking.xcdatamodeld'
  ]

  spec.dependency 'KeychainAccess'
  spec.dependency 'OctopusRemoteClient', SharedPodSpecConfig::VERSION
  spec.dependency 'OctopusGrpcModels', SharedPodSpecConfig::VERSION
  spec.dependency 'OctopusDependencyInjection', SharedPodSpecConfig::VERSION
end
