def build_ree_command(name, output, prefix, usr_dir, tmpdir, rubygems = nil)
  build_command = [
    "mv #{usr_dir} /tmp",
    "mkdir -p #{prefix}",
    "./installer --auto #{prefix} --dont-install-useful-gems --no-dev-docs"
  ]
  build_command << "#{prefix}/bin/ruby /tmp/#{usr_dir}/rubygems-#{rubygems}/setup.rb" if rubygems
  build_command << "mv #{prefix} /app/vendor/#{output}" if prefix != "/app/vendor/#{output}"
  build_command = build_command.join(" && ")

  #sh "vulcan build -v -o #{output}.tgz --prefix #{vulcan_prefix} --source #{name} --command=\"#{build_command}\""
  #s3_upload(tmpdir, output)
end

full_version   = '1.8.7-2012.02'
full_name      = "ruby-enterprise-#{full_version}"
version        = '1.8.7'
major_ruby     = '1.8'
rubygems       = '1.8.24'
name           = "ruby-#{version}"
usr_dir        = "usr"

Dir.mktmpdir("ruby-") do |tmpdir|
  Dir.chdir(tmpdir) do |dir|
    FileUtils.rm_rf("#{tmpdir}/*")

    sh "curl https://rubyenterpriseedition.googlecode.com/files/#{full_name}.tar.gz -s -o - | tar zxf -"

    Dir.chdir("#{full_name}/source") do |source_dir|
      sh "curl -L -o 34ba44f94a62c63ddf02a045b6f4edcd6eab4989.patch https://github.com/RapGenius/rubyenterpriseedition187-330/commit/34ba44f94a62c63ddf02a045b6f4edcd6eab4989.patch"
      sh "curl -L -o 5384967a015be227e16af7a332a50d45e14ed0ad.patch https://github.com/RapGenius/rubyenterpriseedition187-330/commit/5384967a015be227e16af7a332a50d45e14ed0ad.patch"
      sh "curl -L -o tcmalloc.patch https://raw.githubusercontent.com/wayneeseguin/rvm/master/patches/ree/1.8.7/tcmalloc.patch"
      sh "patch -p1 <34ba44f94a62c63ddf02a045b6f4edcd6eab4989.patch"
      sh "patch -p1 <5384967a015be227e16af7a332a50d45e14ed0ad.patch"
      sh "patch -p1 <tcmalloc.patch"
    end

    FileUtils.mkdir_p("#{full_name}/#{usr_dir}")
    Dir.chdir("#{full_name}/#{usr_dir}") do
      sh "curl http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems}.tgz -s -o - | tar xzf -" if major_ruby == "1.8"
    end

    # runtime ruby
    prefix  = "/app/vendor/#{name}"
    build_ree_command(full_name, name, prefix, usr_dir, tmpdir, rubygems)

    # build ruby
    if major_ruby == "1.8"
      output  = "ruby-build-#{version}"
      prefix  = "/tmp/ruby-#{version}"
      build_ree_command(full_name, output, prefix, usr_dir, tmpdir, rubygems)
    end
  end
end
