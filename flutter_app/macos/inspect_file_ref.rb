require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

file_refs = project.objects.grep(Xcodeproj::Project::Object::PBXFileReference).select do |ref|
  ref.path.to_s.include?('WidgetExtension.appex')
end

file_refs.each do |file_ref|
  puts "File Reference Details:"
  puts "  UUID: #{file_ref.uuid}"
  puts "  Path: #{file_ref.path}"
  puts "  Name: #{file_ref.name}"
  puts "  Source Tree: #{file_ref.source_tree}"
  puts "  Explicit File Type: #{file_ref.explicit_file_type}"
  puts "  Last Known File Type: #{file_ref.last_known_file_type}"
end
if file_refs.empty?
  puts "No matching file reference found."
end
