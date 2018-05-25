Pod::Spec.new do |s|

    # Set following to true to use local .git dir as the
    # project source; useful for test/debug of the spec.
    debug = true; 
    # --------------------------------------------------

    s.name          = "Locomote"
    s.version       = "0.8.0"
    s.summary       = "Locomote.sh SDK for iOS"
    s.description   = <<-DESC
iOS SDK for the Locomote.sh mobile asset and content management server.
    DESC
    s.homepage      = "https://github.com/innerfunction/Locomote-ios"
    s.license = {
      :type => "Apache License, Version 2.0",
      :file => "LICENSE" }
    s.author        = { "Julian Goacher" => "julian.goacher@innerfunction.com" }
    s.platform      = :ios
    s.ios.deployment_target = '8.0'

    localSource     = { :git => Dir.pwd+'/.git' };
    remoteSource    = {
        :git => 'https://github.com/innerfunction/Locomote-ios.git',
        :tag => s.version
    };
    s.source        = (debug) ? localSource : remoteSource;

    s.frameworks    = "UIKit", "Foundation"

    s.subspec 'core' do |core|
        core.source_files           = 'Locomote/Locomote.{h,m}',
                                      'Locomote/cms/*.{h,m}',
                                      'Locomote/commands/*.{h,m}',
                                      'Locomote/content/*.{h,m}',
                                      'Locomote/core/*.{h,m}',
                                      'Locomote/forms/*.{h,m}';
        core.public_header_files    = 'Locomote/Locomote.h';
#                                      'Locomote/cms/*.h',
#                                      'Locomote/commands/*.h',
#                                      'Locomote/content/*.h',
#                                      'Locomote/core/*.h';
        core.requires_arc           = true;
        core.compiler_flags         = '-w';
        core.dependency 'Q'
        core.dependency 'SCFFLD'
        core.dependency 'FilePathPattern'
        core.dependency 'GRMustache'
    end

    #s.subspec 'forms' do |forms|
        #forms.source_files          = 'Locomote/forms/*.{h,m}';
        #forms.public_header_files   = 'Locomote/forms/*.h';
        #forms.requires_arc          = true;
        #forms.compiler_flags        = '-w';
        #forms.dependency 'Locomote/core';
    #end

end
