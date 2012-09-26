require 'pkgr/base_app'

module Pkgr
  class RailsApp < BaseApp

    # Creates an executable file for easy launch of the server/console/rake tasks once it is installed.
    # E.g. /usr/bin/my-app console, /usr/bin/my-app server start -p 8080
    def setup_binary
      target = File.join(root, "bin", name)
      Pkgr.mkdir(File.dirname(target))
      FileUtils.cp(File.expand_path("../data/bin/executable", __FILE__), target, :verbose => true)
      FileUtils.chmod 0755, target, :verbose => true
      puts "Correctly set up executable file. Try running './bin/#{name} console'."
    end

    def build_debian_package(host, port = 22)
      puts "Building debian package on '#{host}'..."
      Dir.chdir(root) do
        Pkgr.mkdir("pkg")
        archive = "#{name}-#{version}"
        sh "scp -P #{port} #{File.expand_path("../data/config/pre_boot.rb", __FILE__)} #{host}:/tmp/"
        cmd = %Q{
          git archive #{git_ref} --prefix=#{archive}/ | ssh #{host} -p #{port} 'cat - > /tmp/#{archive}.tar &&
            set -x && rm -rf /tmp/#{archive} &&
            cd /tmp && tar xf #{archive}.tar && cd #{archive} &&
            cat config/boot.rb >> /tmp/pre_boot.rb && cp -f /tmp/pre_boot.rb config/boot.rb &&
            #{debian_steps.join(" &&\n")}'
        }
        sh cmd
        # Fetch the .deb, and put it in the `pkg` directory
        sh "scp -P #{port} #{host}:/tmp/#{name}_#{version}* pkg/"
      end
    end

    def debian_steps
      target_vendor = "vendor/bundle/ruby/1.9.1"
      [
        # "sudo apt-get install #{debian_runtime_dependencies(true).join(" ")} -y",
        "sudo apt-get install #{debian_build_dependencies(true).join(" ")} -y",
        "cd /tmp && if [ ! -f node-v0.8.7-linux-x64.tar.gz ]; then wget http://nodejs.org/dist/v0.8.7/node-v0.8.7-linux-x64.tar.gz; fi && tar xzf node-v0.8.7-linux-x64.tar.gz && cd -",
        # Vendor bundler
        "gem1.9.1 install bundler --no-ri --no-rdoc --version #{bundler_version} -i #{target_vendor}",
        "GEM_HOME='#{target_vendor}' #{target_vendor}/bin/bundle install --deployment --without test development",
        "cd #{root} && git init .",
        "PATH=$PATH:/tmp/node-v0.8.7-linux-x64/bin GEM_HOME='#{target_vendor}' #{target_vendor}/bin/bundle exec rake assets:precompile",
        "rm -rf #{target_vendor}/{cache,doc}",
        "dpkg-buildpackage -us -uc -d"
      ]
    end

    private

    def bundler_version
      @config.fetch('bundler_version') { '1.1.3' }
    end

  end
end
