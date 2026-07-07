require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

host_target = project.targets.find { |t| t.name == 'Runner' }
if host_target.nil?
  puts "Runner target not found."
  exit 1
end

host_target.build_phases.grep(Xcodeproj::Project::Object::PBXShellScriptBuildPhase).each do |phase|
  puts "=================================================="
  puts "Shell Script Phase: Name=#{phase.name || 'Unnamed'}, Shell=#{phase.shell_path}"
  puts "Script Content:"
  puts phase.shell_script
end
