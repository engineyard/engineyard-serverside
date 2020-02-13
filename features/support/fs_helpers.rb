require 'pathname'
module FsHelpers
  def project_root
    Pathname.new(File.expand_path(File.join(__FILE__, '..', '..', '..')))
  end

  def data_path
    project_root.join('tmp', 'data')
  end

  def setup_data_path
    data_path.mkpath
  end

  def cleanup_data_path
    data_path.rmtree if data_path.exist?
  end

  def app_path
    data_path.join(app_name)
  end

  def setup_app_path
    app_path.mkpath
  end

  def release_path
    app_path.join('20200212024800')
  end

  def setup_release_path
    release_path.mkpath
  end

  def deploy_hooks_path
    release_path.join('deploy')
  end

  def setup_deploy_hooks_path
    deploy_hooks_path.mkpath
  end

  def cleanup_deploy_hooks_path
    deploy_hooks_path.rmtree if deploy_hooks_path.exist?
  end

  def shared_app_path
    app_path.join('shared')
  end

  def shared_hooks_path
    shared_app_path.join('hooks')
  end

  def setup_shared_hooks_path
    shared_hooks_path.mkpath
  end

  def cleanup_shared_hooks_path
    shared_hooks_path.rmtree if shared_hooks_path.exist?
  end

  def service_path(service)
    shared_hooks_path.join(service)
  end

  def setup_service_path(service)
    service_path(service).mkpath
  end

  def setup_fs
    setup_deploy_hooks_path
    setup_shared_hooks_path
  end

  def cleanup_fs
    cleanup_data_path
  end

end

World(FsHelpers)
