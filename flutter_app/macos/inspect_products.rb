require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  if target.respond_to?(:product_reference)
    prod_ref = target.product_reference
    if prod_ref
      puts "Target: #{target.name}"
      puts "  Product Ref UUID: #{prod_ref.uuid}"
      puts "  Product Ref Path: #{prod_ref.path}"
      puts "  Product Ref Name: #{prod_ref.name}"
    else
      puts "Target: #{target.name} has nil product reference."
    end
  else
    puts "Target: #{target.name} has no product reference method."
  end
end
