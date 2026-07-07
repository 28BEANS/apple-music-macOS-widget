require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WidgetExtension' }
if target.nil?
  puts "WidgetExtension target not found."
  exit 1
end

target.build_configurations.each do |config|
  puts "Configuration: #{config.name}"
  config.build_settings.keys.sort.each do |key|
    puts "  #{key} = #{config.build_settings[key]}"
  end
end
