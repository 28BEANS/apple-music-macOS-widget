require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Completely purging all historical WidgetExtension references..."

# 1. Remove targets named WidgetExtension
project.targets.select { |t| t.name == 'WidgetExtension' }.each do |target|
  target.remove_from_project
  puts "   - Removed WidgetExtension target."
end

# 2. Remove all PBXBuildFile entries with nil references or containing WidgetExtension
project.objects.grep(Xcodeproj::Project::Object::PBXBuildFile).select do |bf|
  bf.file_ref.nil? || 
  bf.file_ref.path.to_s.include?('WidgetExtension') || 
  bf.file_ref.name.to_s.include?('WidgetExtension') ||
  bf.to_s.include?('WidgetExtension')
end.each do |bf|
  bf.remove_from_project
  puts "   - Purged build file: #{bf.uuid}"
end

# 3. Remove all target dependencies pointing to WidgetExtension or nil targets
project.targets.each do |t|
  t.dependencies.select { |dep| dep.target.nil? || dep.target.name == 'WidgetExtension' }.each do |dep|
    dep.remove_from_project
    puts "   - Removed dependency: #{dep.uuid} from target #{t.name}"
  end
end

# 4. Remove all file references matching WidgetExtension
project.objects.grep(Xcodeproj::Project::Object::PBXFileReference).select do |ref|
  ref.path.to_s.include?('WidgetExtension') || ref.name.to_s.include?('WidgetExtension')
end.each do |ref|
  ref.remove_from_project
  puts "   - Purged file reference: path=#{ref.path}, name=#{ref.name}"
end

# 5. Remove groups named WidgetExtension
project.main_group.children.select { |c| c.name == 'WidgetExtension' }.each do |group|
  group.remove_from_project
  puts "   - Removed WidgetExtension group."
end

# Save the absolute clean project file
project.save

# 6. Re-open to start fresh creation
project = Xcodeproj::Project.open(project_path)
host_target = project.targets.find { |t| t.name == 'Runner' }

puts "🚀 Re-creating WidgetExtension target..."
target = project.new_target(:app_extension, 'WidgetExtension', :osx, '14.0')

group = project.main_group.find_subpath('WidgetExtension', true)
group.set_path('WidgetExtension')
puts "   - Created group and set path to: WidgetExtension"

# Add Swift, Info.plist, and entitlements
swift_ref = group.new_file('WidgetExtension.swift')
plist_ref = group.new_file('Info.plist')
entitlements_ref = group.new_file('WidgetExtension.entitlements')

target.add_file_references([swift_ref])

# Configure target build settings
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'WidgetExtension'
  config.build_settings['PRODUCT_MODULE_NAME'] = 'WidgetExtension'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.musicWidget.WidgetExtension'
  config.build_settings['INFOPLIST_FILE'] = 'WidgetExtension/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'WidgetExtension/WidgetExtension.entitlements'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks @executable_path/Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
  config.build_settings['PROVISIONING_PROFILE'] = ''
end

# Set up target dependency
host_target.add_dependency(target)

# Add Embed phase and add the product reference
embed_phase = host_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' || phase.dst_subfolder_spec == '13' }
if embed_phase.nil?
  puts "📦 Creating new Copy Files phase 'Embed App Extensions'..."
  embed_phase = host_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13' # 13 corresponds to PlugIns
end
# Set dst_path to empty since subfolder spec 13 already points to Wrapper's PlugIns directory
embed_phase.dst_path = ''

widget_product = target.product_reference
embed_phase.add_file_reference(widget_product)

project.save
puts "🎉 Successfully re-configured WidgetExtension clean target in Runner.xcodeproj."
