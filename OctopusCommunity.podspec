require_relative 'SharedPodSpecConfig'

Pod::Spec.new do |spec|
  spec.name         = 'OctopusCommunity'
  spec.module_name  = 'Octopus'
  spec.summary      = 'Octopus Community SDK'
  spec.version      = SharedPodSpecConfig::VERSION
  spec.homepage     = SharedPodSpecConfig::GITHUB_PAGE
  spec.license      = SharedPodSpecConfig::LICENSE
  spec.author       = SharedPodSpecConfig::AUTHOR
  spec.source       = SharedPodSpecConfig::SOURCE
  
  spec.ios.deployment_target = SharedPodSpecConfig::IOS_DEPLOYMENT_TARGET
  spec.swift_version = SharedPodSpecConfig::SWIFT_VERSION
  
  spec.source_files = 'Sources/Octopus/**/*.swift'

  spec.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-package-name #{SharedPodSpecConfig::PACKAGE_NAME}'
  }

  spec.dependency 'OctopusCommunityCore', SharedPodSpecConfig::VERSION
  spec.dependency 'OctopusCommunityDependencyInjection', SharedPodSpecConfig::VERSION
end
