# Changelog
All notable changes to this project will be documented in this file.
## 0.1.7
### Added
- Allow to config redis and queue

```ruby
Dwf.config do |config|
  config.opts = { url 'redis://127.0.0.1:6379' }
  config.namespace = 'dwf'
end
```

## 0.1.6
### Added
- Sidekiq batch callback: separate batches

## 0.1.5
### Added
- add github action with build and public gem flow

## 0.1.4
### Added
- Add testes
- add github action

### Fixed
- Remove Sidekiq pro by default

---
## 0.1.3
### Added
- Support both build in and [Sidekiq batches](https://github.com/mperham/sidekiq/wiki/Batches) callback
- Update readme

### Fixed
- Fix bug require development gem

---
## 0.1.2
### Added
- Support [Sidekiq batches](https://github.com/mperham/sidekiq/wiki/Batches) callback
- Update readme

### Fixed
- fix typo and remove development gem

---
## 0.1.0
### Added
- init app with basic idea following [Gush](https://github.com/chaps-io/gush) concept
- Support build in callback
