def whyrun_supported?
  true
end

action :create do
  user = new_resource.user
  domain = new_resource.domain
  environment = new_resource.environment
  unicorn_workers = new_resource.unicorn_workers

  app_name = new_resource.app_name
  app_dir  = new_resource.app_dir


  unless @current_resource.exists
    converge_by "create directories" do
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
    end

    converge_by "Setup application user: #{user}" do
      link "/home/#{user}/#{app_name}" do
        to app_dir
      end

      sudo "#{user}_#{app_name}" do
        user user
        commands ["/usr/bin/sv * #{app_name}*"]
        host "ALL"
        nopasswd true
      end
    end
  end

  converge_by "Configure application: #{app_name}" do
    template "/etc/logrotate.d/#{app_name}-application" do
      owner "root"
      group "root"
      mode 0644
      cookbook 'lazy_brigade'
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
      cookbook 'lazy_brigade'      
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
      cookbook new_resource.cookbook
      owner user
      group user
      variables app_path: app_dir,
        worker_processes: unicorn_workers,
        listen: "/tmp/#{app_name}-rails.sock",
        environment: environment
    end

    template "#{app_dir}/shared/config/secrets.yml" do
      source 'secrets.yml.erb'
      cookbook 'lazy_brigade'
      owner user
      group user
      variables secrets: new_resource.app_secrets,
        environment: environment
    end

    template "#{node['nginx']['dir']}/sites-available/#{app_name}-site-htpasswd.conf" do
      only_if { node['app-protected'] }
      source "site-htpasswd.erb"
      cookbook 'lazy_brigade'
      owner 'www-data'
      group 'www-data'
      mode 0640
      variables user: node['auth_user'],
        hash: node['auth_pass']
    end

    if new_resource.dotenv
      template "#{app_dir}/shared/.env" do
        source "dotenv.erb"
        cookbook 'lazy_brigade'
        owner user
        group user
        variables env: node['dotenv']
      end
    end

    template "#{node['nginx']['dir']}/sites-available/#{app_name}.conf" do
      source "nginx-application.erb"
      mode "0644"
      cookbook new_resource.cookbook
      variables app_path: app_dir,
        domain: domain,
        app_name: app_name,
        backend: "unix:/tmp/#{app_name}-rails.sock",
        protected_site: node["app-protected"],
        development_mode: environment == 'development'
      notifies :reload, "service[nginx]"
    end

    nginx_site "#{app_name}.conf"
  end

end

def load_current_resource
  @current_resource = Chef::Resource::LazyBrigade.new(@new_resource.domain)
  @current_resource.exists = ::File.exists?(@new_resource.app_dir)
  @current_resource
end
