require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  puts "Target: #{target.name}"
  target.build_configurations.each do |config|
    base_ref = config.base_configuration_reference
    if base_ref
      puts "  Configuration: #{config.name}"
      puts "    Base Config Path: #{base_ref.path}"
      puts "    Base Config Name: #{base_ref.name}"
    else
      puts "  Configuration: #{config.name} has no base configuration."
    end
  end
end
