require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WidgetExtension' }
host_target = project.targets.find { |t| t.name == 'Runner' }

puts "WidgetExtension Product Reference UUID: #{target.product_reference.uuid}"

embed_phase = host_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' || phase.dst_subfolder_spec == '13' }
puts "Embed App Extensions Copy Files:"
embed_phase.files.each do |file|
  if file.file_ref
    puts "  - File Ref UUID: #{file.file_ref.uuid}, Path: #{file.file_ref.path}"
  else
    puts "  - Nil File Ref"
  end
end
