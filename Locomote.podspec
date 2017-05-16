Pod::Spec.new do |s|

    # Set following to true to use local .git dir as the
    # project source; useful for test/debug of the spec.
    debug = true; 
    # --------------------------------------------------

    s.name        = "Locomote"
    s.version     = "0.8.0"
    s.summary     = "Locomote.sh SDK for iOS"
    s.description = <<-DESC
iOS SDK for the Locomote.sh mobile asset and content management server.
    DESC
    s.homepage = "https://github.com/innerfunction/Locomote-ios"
    s.license = {
      :type => "Apache License, Version 2.0",
      :file => "LICENSE" }
    s.author = { "Julian Goacher" => "julian.goacher@innerfunction.com" }
    s.platform = :ios
    s.ios.deployment_target = '8.0'

    localSource = { :git => Dir.pwd+'/.git' };
    remoteSource = { :git => 'https://github.com/innerfunction/Locomote-ios.git', :tag => s.version };
    s.source = (debug) ? localSource : remoteSource;

    s.frameworks = "UIKit", "Foundation"

    s.subspec 'AM' do |am|
        am.source_files = 'Locomote/commands/*.{h,m}', 'Locomote/content/*.{h,m}', 'Locomote/ams/*.{h,m}';
        am.public_header_files = 'Locomote/commands/*.h', 'Locomote/content/*.h', 'Locomote/ams/*.h';
        am.requires_arc = true;
        am.compiler_flags = '-w';
        am.dependency 'Q'
        am.dependency 'SCFFLD/Core'
        am.dependency 'SCFFLD/HTTP'
        am.dependency 'SCFFLD/DB'
        am.dependency 'GRMustache'
    end

    s.subspec 'CM' do |cm|
        cm.source_files = 'Locomote/cms/*.{h,m}';
        cm.public_header_files = 'Locomote/cms/*.h';
        cm.requires_arc = true;
        cm.compiler_flags = '-w';
        cm.dependency 'Locomote/AM';
    end

end
