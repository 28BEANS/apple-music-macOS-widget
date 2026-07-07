require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Adjusting signing settings for all targets in #{project_path}..."

# 1. Force ProvisioningStyle to Manual for all targets in attributes
project.root_object.attributes["TargetAttributes"] ||= {}
project.targets.each do |target|
  project.root_object.attributes["TargetAttributes"][target.uuid] ||= {}
  project.root_object.attributes["TargetAttributes"][target.uuid]["ProvisioningStyle"] = 'Manual'
  puts "   - Set ProvisioningStyle to 'Manual' for target: #{target.name}"
end

# 2. Update build configurations for all targets to use ad-hoc signing
project.targets.each do |target|
  puts "   - Updating build settings for target: #{target.name}"
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_IDENTITY'] = '-'
    config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
    config.build_settings['DEVELOPMENT_TEAM'] = ''
    config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
    config.build_settings['PROVISIONING_PROFILE'] = ''
    
    # Configure App Sandbox explicitly per target type
    if target.name == 'Runner'
      config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
    elsif target.name == 'WidgetExtension'
      config.build_settings['ENABLE_APP_SANDBOX'] = 'YES'
      config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    end
  end
end

project.save
puts "🎉 Code signing settings successfully adjusted to Ad-Hoc manual signing."
