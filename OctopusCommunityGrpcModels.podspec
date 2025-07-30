require_relative 'SharedPodSpecConfig'

Pod::Spec.new do |spec|
  spec.name         = 'OctopusCommunityGrpcModels'
  spec.module_name  = 'OctopusGrpcModels'
  spec.summary      = 'Grpc models of the Octopus Community SDK.'
  spec.version      = SharedPodSpecConfig::VERSION
  spec.homepage     = SharedPodSpecConfig::GITHUB_PAGE
  spec.license      = SharedPodSpecConfig::LICENSE
  spec.author       = SharedPodSpecConfig::AUTHOR
  spec.source       = SharedPodSpecConfig::SOURCE
  
  spec.ios.deployment_target = SharedPodSpecConfig::IOS_DEPLOYMENT_TARGET
  spec.swift_version = SharedPodSpecConfig::SWIFT_VERSION
  
  spec.source_files = 'Sources/OctopusGrpcModels/**/*.swift'

  spec.dependency 'OctopusCommunityDependencyInjection', SharedPodSpecConfig::VERSION
  spec.dependency 'SwiftProtobuf'
  spec.dependency 'gRPC-Swift'
end
