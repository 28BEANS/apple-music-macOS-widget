require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Runner' }
if target.nil?
  puts "Runner target not found."
  exit 1
end

target.build_configurations.each do |config|
  puts "Configuration: #{config.name}"
  ['ENABLE_APP_SANDBOX', 'ENABLE_HARDENED_RUNTIME', 'CODE_SIGN_ENTITLEMENTS'].each do |key|
    puts "  #{key} = #{config.build_settings[key]}"
  end
end
