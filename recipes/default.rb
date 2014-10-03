include_recipe('nginx')
include_recipe('runit')

%w/screen curl vim sysdig/.each do |pkg|
  package pkg
end

user = node['app-user']
domain = node["app-domain"]
environment = node["app-environment"]
app_name = domain.split('.', 2)[0]
app_dir = "/srv/#{app_name}"

directory app_dir do
  owner user
  group user
end

directory "#{app_dir}/shared" do
  owner user
  group user
end

directory "#{app_dir}/shared/config" do
  owner user
  group user
end

link "/home/#{user}/#{app_name}" do
  to app_dir
end

sudo user do
  user user
  commands ["/usr/bin/sv * #{app_name}*"]
  host "ALL"
  nopasswd true
end

template "/etc/logrotate.d/#{app_name}-application" do
  owner "root"
  group "root"
  mode 0644
  source "application-logrotate.erb"
  variables(
    :logs => "#{app_dir}/shared/log",
    :pidfile => "#{app_dir}/current/tmp/pids/unicorn.pid",
    :rotate => 90
  )
end

runit_service "#{app_name}_rails" do
  default_logger true
  run_template_name "rails_app"
  options({
    :home_path => "/home/#{user}",
    :app_path => app_dir,
    :target_user => user,
    :target_ruby => "default",
    :target_env => environment
  })
end

template "#{app_dir}/shared/config/unicorn.rb" do
  source 'unicorn.rb.erb'
  owner user
  group user
  variables :app_path => app_dir,
            :worker_processes => 1,
            :listen => "/tmp/#{app_name}-rails.sock",
            :environment => environment
end

template "#{app_dir}/shared/config/secrets.yml" do  
  source 'secrets.yml.erb'
  owner user
  group user
  variables secrets: node['secrets'],
            evnironment: environment
end


template "#{node['nginx']['dir']}/sites-available/#{app_name}-site-htpasswd.conf" do
  only_if { node['app-protected'] }
  source "site-htpasswd.erb"
  owner 'www-data'
  group 'www-data'
  mode 0640
  variables user: node['auth_user'],
            hash: node['auth_pass']     
end

template "#{node['nginx']['dir']}/sites-available/nginx-application.conf" do
    source "nginx-application.erb"
    mode "0644"
    variables :app_path => app_dir,
              :domain => domain,
              :app_name => app_name,
              :backend => "unix:/tmp/#{app_name}-rails.sock",
              :protected_site => node["app-protected"],
              :development_mode => environment == 'development'
    notifies :reload, resources(:service => "nginx")
end

nginx_site "nginx-application.conf"
