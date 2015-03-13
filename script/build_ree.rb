require 'tmpdir'
require 'fileutils'

def sh(command)
  command = "cd #{Dir.pwd} && #{command}"
  puts command
  system command
end

def s3_upload(tmpdir, name)
  s3_bucket_name = ENV.fetch('S3_BUCKET_NAME')
  content_type = "application/x-gzip"
  sh %(curl -i -XPUT -T #{tmpdir}/#{name}.tgz -H 'Host: #{s3_bucket_name}.s3.amazonaws.com' -H "Content-Type: #{content_type}" https://#{s3_bucket_name}.s3.amazonaws.com/#{name}.tgz)
end

def build_ree_command(name, output, prefix, usr_dir, tmpdir, rubygems = nil)
  build_command = [
    "mv #{usr_dir} /tmp",
    "mkdir -p #{prefix}",
    "./installer --auto #{prefix} --dont-install-useful-gems --no-dev-docs"
  ]
  build_command << "#{prefix}/bin/ruby /tmp/#{usr_dir}/rubygems-#{rubygems}/setup.rb" if rubygems
  build_command = build_command.join(" && ")

  Dir.chdir(name) do
    sh build_command
  end

  Dir.chdir(prefix) do
    sh "tar -czvf #{tmpdir}/#{output}.tgz ."
  end

  s3_upload(tmpdir, output)
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

    prefix = "/tmp/#{name}"
    build_ree_command(full_name, "ruby-build-1.8.7", prefix, usr_dir, tmpdir, rubygems)

    FileUtils.mkdir_p("#{full_name}/#{usr_dir}")
    Dir.chdir("#{full_name}/#{usr_dir}") do
      sh "curl http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems}.tgz -s -o - | tar xzf -" if major_ruby == "1.8"
    end

    # runtime ruby
    prefix  = "/app/vendor/#{name}"
    build_ree_command(full_name, name, prefix, usr_dir, tmpdir, rubygems)
  end
end
