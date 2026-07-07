require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WidgetExtension' }
if target.nil?
  puts "WidgetExtension target not found."
  exit 1
end

puts "Build Phases for WidgetExtension target:"
target.build_phases.each do |phase|
  puts "--------------------------------------------------"
  puts "Phase Type: #{phase.class}"
  puts "Phase Name: #{phase.respond_to?(:name) ? phase.name : 'Unnamed'}"
  puts "  Files:"
  phase.files.each do |file|
    if file.file_ref
      name = file.file_ref.respond_to?(:name) ? file.file_ref.name : nil
      path = file.file_ref.respond_to?(:path) ? file.file_ref.path : nil
      puts "    - Name: #{name || 'nil'}, Path: #{path || 'nil'}, Type: #{file.file_ref.class}"
    else
      puts "    - Nil file reference"
    end
  end
end
