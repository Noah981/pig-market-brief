require 'xcodeproj'
require 'fileutils'
require 'json'
root = File.expand_path('../flutter_app', __dir__)
ios = File.join(root, 'ios')
template = File.join(root, 'ios_widget')
project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target missing' unless runner
FileUtils.cp(File.join(template, 'AppDelegate.swift'), File.join(ios, 'Runner', 'AppDelegate.swift'))
folder = File.join(ios, 'PigPriceWidgets'); FileUtils.mkdir_p(folder)
%w[PriceSnapshot.swift PriceViews.swift PigPriceWidgets.swift].each { |name| FileUtils.cp(File.join(template, name), folder) }
assets = File.join(folder, 'Assets.xcassets', 'PigLogo.imageset'); FileUtils.mkdir_p(assets)
FileUtils.cp(File.join(root, 'assets/images/dondonhae_symbol.png'), File.join(assets, 'pig.png'))
File.write(File.join(assets, 'Contents.json'), JSON.generate({images: [{filename: 'pig.png', idiom: 'universal'}], info: {author: 'xcode', version: 1}}))
File.write(File.join(folder, 'Assets.xcassets', 'Contents.json'), JSON.generate({info: {author: 'xcode', version: 1}}))
ext = project.targets.find { |t| t.name == 'PigPriceWidgets' } || project.new_target(:app_extension, 'PigPriceWidgets', :ios, '17.0')
group = project.main_group.find_subpath('PigPriceWidgets', true); group.set_source_tree('<group>'); group.path = 'PigPriceWidgets'
%w[PriceSnapshot.swift PriceViews.swift PigPriceWidgets.swift].each do |name|
  ref = group.files.find { |f| f.path == name } || group.new_file(name)
  ext.source_build_phase.add_file_reference(ref, true)
  runner.source_build_phase.add_file_reference(ref, true) if name == 'PriceSnapshot.swift'
end
ref = group.files.find { |f| f.path == 'Assets.xcassets' } || group.new_file('Assets.xcassets')
ext.resources_build_phase.add_file_reference(ref, true)
info = {'CFBundleDisplayName' => '돈돈해 돈가', 'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleExecutable' => '$(EXECUTABLE_NAME)', 'CFBundleName' => '$(PRODUCT_NAME)', 'CFBundlePackageType' => 'XPC!', 'CFBundleShortVersionString' => '1.8.1', 'CFBundleVersion' => '18', 'NSExtension' => {'NSExtensionPointIdentifier' => 'com.apple.widgetkit-extension'}}
Xcodeproj::Plist.write_to_path(info, File.join(folder, 'Info.plist'))
entitlements = {'com.apple.security.application-groups' => ['group.com.example.dondonhae.market']}
Xcodeproj::Plist.write_to_path(entitlements, File.join(folder, 'PigPriceWidgets.entitlements'))
Xcodeproj::Plist.write_to_path(entitlements, File.join(ios, 'Runner', 'Runner.entitlements'))
ext.build_configurations.each do |config|
  config.build_settings.merge!({'PRODUCT_NAME' => '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.example.dondonhae.PigPriceWidgets', 'INFOPLIST_FILE' => 'PigPriceWidgets/Info.plist', 'CODE_SIGN_ENTITLEMENTS' => 'PigPriceWidgets/PigPriceWidgets.entitlements', 'SWIFT_VERSION' => '5.0', 'IPHONEOS_DEPLOYMENT_TARGET' => '17.0', 'TARGETED_DEVICE_FAMILY' => '1,2', 'SKIP_INSTALL' => 'YES', 'APPLICATION_EXTENSION_API_ONLY' => 'YES', 'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'})
end
runner.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner.add_dependency(ext) unless runner.dependencies.any? { |d| d.target == ext }
embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Widget Extension' } || runner.new_copy_files_build_phase('Embed Widget Extension')
embed.dst_subfolder_spec = '13'
build_file = embed.add_file_reference(ext.product_reference, true); build_file.settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
plist_path = File.join(ios, 'Runner', 'Info.plist'); plist = Xcodeproj::Plist.read_from_path(plist_path)
plist['CFBundleURLTypes'] = [{'CFBundleURLSchemes' => ['dondonhae']}]
plist['NSLocationWhenInUseUsageDescription'] = '현재 지역의 날씨와 주변 질병 거리를 확인합니다.'
plist['NSAppTransportSecurity'] = {'NSAllowsArbitraryLoads' => true}
Xcodeproj::Plist.write_to_path(plist, plist_path)
# Widget snapshots use a separate simulator harness, with no mock data in production.
preview_source = File.join(template, 'WidgetPreviewApp.swift')
if File.exist?(preview_source)
  FileUtils.cp(preview_source, File.join(folder, 'WidgetPreviewApp.swift'))
  preview = project.targets.find { |t| t.name == 'WidgetPreview' } || project.new_target(:application, 'WidgetPreview', :ios, '17.0')
  %w[PriceSnapshot.swift PriceViews.swift WidgetPreviewApp.swift].each { |name| preview.source_build_phase.add_file_reference(group.files.find { |f| f.path == name } || group.new_file(name), true) }
  preview.resources_build_phase.add_file_reference(ref, true)
  preview.build_configurations.each { |c| c.build_settings.merge!({'PRODUCT_NAME' => '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.example.dondonhae.WidgetPreview', 'GENERATE_INFOPLIST_FILE' => 'YES', 'SWIFT_VERSION' => '5.0', 'IPHONEOS_DEPLOYMENT_TARGET' => '17.0', 'TARGETED_DEVICE_FAMILY' => '1,2', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) WIDGET_PREVIEW'}) }
  scheme = Xcodeproj::XCScheme.new; scheme.add_build_target(preview); scheme.set_launch_target(preview); scheme.save_as(File.join(ios, 'Runner.xcodeproj'), 'WidgetPreview', true)
end
project.save
podfile = File.join(ios, 'Podfile')
if File.exist?(podfile)
  contents = File.read(podfile).sub(/^#?\s*platform :ios,.*$/, "platform :ios, '17.0'")
  File.write(podfile, contents)
end
puts 'iOS app group, widget extension, deep link and snapshot target configured'
