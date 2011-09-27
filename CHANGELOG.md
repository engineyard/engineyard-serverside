## 1.4.16

Bugfixes:

  - Deployment previously failed when the git repo had only a single commit.

## 1.4.15

Features:

  - Add 'before_compile_assets.rb' and 'after_compile_assets.rb' deploy hooks
  - Run `rake assets:precompile` if it is available and enabled for Rails 3.1 apps
  - Treat 'public/assets' as a shared directory if it is managed by 'rake assets:precompile'
  - Beta Node.js support for EY Labs

## 1.3.6

Bugfixes:

  - Abort deploy when `git fetch` fails
