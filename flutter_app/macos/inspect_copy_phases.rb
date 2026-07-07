require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  puts "Target: #{target.name}"
  target.copy_files_build_phases.each do |phase|
    puts "  Copy Files Phase: Name=#{phase.name || 'Unnamed'}, DestSubfolderSpec=#{phase.dst_subfolder_spec}, DestPath=#{phase.dst_path}"
    phase.files.each do |file|
      if file.file_ref
        puts "    - File Ref: Path=#{file.file_ref.path}, Name=#{file.file_ref.name}, Class=#{file.file_ref.class}"
      else
        puts "    - Nil File Ref (File ID: #{file.uuid})"
      end
    end
  end
end
