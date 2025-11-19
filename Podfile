platform :ios, '17.0'
use_frameworks!

target 'hummingbird' do
  pod 'mozjpeg', '~> 3.3'
  pod 'libavif'
  pod 'SDWebImageWebPCoder', '~> 0.14.6'
  pod 'ffmpeg-kit-ios-full', :podspec => 'https://raw.githubusercontent.com/luthviar/ffmpeg-kit-ios-full/main/ffmpeg-kit-ios-full.podspec'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
  
  # 为 CocoaPods 脚本阶段禁用沙盒以避免 rsync 权限问题
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
  
  # 为主项目禁用沙盒，因为 CocoaPods 脚本在主项目中运行
  installer.generated_aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate_target.user_project.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end