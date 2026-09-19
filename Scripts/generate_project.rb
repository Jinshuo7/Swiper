#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates Swiper.xcodeproj from the source tree using the xcodeproj gem.
#
# Regenerate after adding or removing source files:
#   gem install --user-install xcodeproj
#   ruby Scripts/generate_project.rb
#
# The project is committed, so this script is only needed when the file layout
# changes. See AGENTS.md.

require "xcodeproj"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "Swiper.xcodeproj")
DEPLOYMENT_TARGET = "17.0"

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

def settings(target, values)
  target.build_configurations.each do |config|
    values.each do |key, value|
      config.build_settings[key] = value
    end
  end
end

def add_sources(project, target, directory)
  Dir.glob(File.join(ROOT, directory, "**", "*.swift")).sort.each do |absolute|
    relative = absolute.sub("#{ROOT}/", "")
    reference = project.main_group.new_file(relative)
    target.source_build_phase.add_file_reference(reference)
  end
end

app = project.new_target(:application, "Swiper", :ios, DEPLOYMENT_TARGET)
kit = project.new_target(:framework, "SwiperKit", :ios, DEPLOYMENT_TARGET)
unit_tests = project.new_target(:unit_test_bundle, "SwiperKitTests", :ios, DEPLOYMENT_TARGET)
ui_tests = project.new_target(:ui_test_bundle, "SwiperUITests", :ios, DEPLOYMENT_TARGET)

project.build_configurations.each do |config|
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = DEPLOYMENT_TARGET
  config.build_settings["SWIFT_VERSION"] = "5.0"
end

# --- SwiperKit -----------------------------------------------------------------
add_sources(project, kit, "SwiperKit")
settings(kit, {
  "PRODUCT_BUNDLE_IDENTIFIER" => "com.swiper.SwiperKit",
  "PRODUCT_NAME" => "SwiperKit",
  "DEFINES_MODULE" => "YES",
  "SKIP_INSTALL" => "YES",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "CODE_SIGN_STYLE" => "Automatic",
  "CURRENT_PROJECT_VERSION" => "1",
  "MARKETING_VERSION" => "1.0",
  "SWIFT_EMIT_LOC_STRINGS" => "YES",
  "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
})

# --- Swiper --------------------------------------------------------------------
add_sources(project, app, "Swiper")
assets = project.main_group.new_file("Swiper/Resources/Assets.xcassets")
app.resources_build_phase.add_file_reference(assets)
settings(app, {
  "PRODUCT_BUNDLE_IDENTIFIER" => "com.swiper.app",
  "PRODUCT_NAME" => "Swiper",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "INFOPLIST_KEY_CFBundleDisplayName" => "Swiper",
  "INFOPLIST_KEY_NSPhotoLibraryUsageDescription" =>
    "Swiper shows your photos one at a time so you can keep, favorite or queue them for deletion. Favorites and confirmed deletions change your library. Everything stays on this device.",
  "INFOPLIST_KEY_UILaunchScreen_Generation" => "YES",
  "INFOPLIST_KEY_UIApplicationSceneManifest_Generation" => "YES",
  "INFOPLIST_KEY_UISupportedInterfaceOrientations" => "UIInterfaceOrientationPortrait",
  "TARGETED_DEVICE_FAMILY" => "1",
  "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
  "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME" => "AccentColor",
  "CODE_SIGN_STYLE" => "Automatic",
  "CURRENT_PROJECT_VERSION" => "1",
  "MARKETING_VERSION" => "1.0",
  "SWIFT_EMIT_LOC_STRINGS" => "YES",
  "ENABLE_PREVIEWS" => "YES",
  "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks"],
})
app.add_dependency(kit)
app.frameworks_build_phase.add_file_reference(kit.product_reference)
embed = app.new_copy_files_build_phase("Embed Frameworks")
embed.dst_subfolder_spec = "10"
embed_build_file = embed.add_file_reference(kit.product_reference)
embed_build_file.settings = { "ATTRIBUTES" => %w[CodeSignOnCopy RemoveHeadersOnCopy] }

# --- SwiperKitTests ------------------------------------------------------------
add_sources(project, unit_tests, "SwiperKitTests")
settings(unit_tests, {
  "PRODUCT_BUNDLE_IDENTIFIER" => "com.swiper.SwiperKitTests",
  "PRODUCT_NAME" => "SwiperKitTests",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "CODE_SIGN_STYLE" => "Automatic",
  "SWIFT_EMIT_LOC_STRINGS" => "YES",
  "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/Swiper.app/Swiper",
  "BUNDLE_LOADER" => "$(TEST_HOST)",
  "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
})
unit_tests.add_dependency(kit)
unit_tests.add_dependency(app)
unit_tests.frameworks_build_phase.add_file_reference(kit.product_reference)

# --- SwiperUITests -------------------------------------------------------------
add_sources(project, ui_tests, "SwiperUITests")
settings(ui_tests, {
  "PRODUCT_BUNDLE_IDENTIFIER" => "com.swiper.SwiperUITests",
  "PRODUCT_NAME" => "SwiperUITests",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "CODE_SIGN_STYLE" => "Automatic",
  "TEST_TARGET_NAME" => "Swiper",
})
ui_tests.add_dependency(app)

# --- Shared scheme -------------------------------------------------------------
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(kit)
scheme.set_launch_target(app)
scheme.add_test_target(unit_tests)
scheme.add_test_target(ui_tests)
scheme.save_as(PROJECT_PATH, "Swiper", true)

project.save
puts "Generated #{PROJECT_PATH}"
