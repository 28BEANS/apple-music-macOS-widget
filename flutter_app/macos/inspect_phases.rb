require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

host_target = project.targets.find { |t| t.name == 'Runner' }
if host_target.nil?
  puts "Runner target not found."
  exit 1
end

puts "Build Phases for Runner target:"
host_target.build_phases.each do |phase|
  puts "--------------------------------------------------"
  puts "Phase Type: #{phase.class}"
  puts "Phase Name: #{phase.respond_to?(:name) ? phase.name : 'Unnamed'}"
  if phase.respond_to?(:dst_subfolder_spec)
    puts "  Destination Subfolder Spec: #{phase.dst_subfolder_spec}"
    puts "  Destination Path: #{phase.dst_path}"
  end
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
