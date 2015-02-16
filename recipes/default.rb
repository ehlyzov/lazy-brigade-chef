node['ext-packages'].each do |pkg|
  package pkg
end

if apps = node['lazy-brigade-apps']
  apps.each do |app|
    lazy_brigade node[app]['domain'] do
      user node[app]['user']
      environment node[app]['environment']
      unicorn_workers node[app]['unicorn-workers']
      app_secrets node[app]['secrets']
      dotenv node[app]['dotenv']
    end
  end
end
